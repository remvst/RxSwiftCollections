// https://github.com/Quick/Quick

import Quick
import Nimble
import RxSwiftCollections
import RxSwift
import RxTest
import RxBlocking

class TestObserver<T>: ObserverType {
    
    var values: [T] = []
    private let valueSemaphore = DispatchSemaphore(value: 0)
    
    var errors: [Error] = []
    private let errorSemaphore = DispatchSemaphore(value: 0)
    
    func assertComplete() {
        assert(1 == 2, "Expected complete")
    }
    
    func awaitCount(_ count: Int, timeout: TimeInterval = 5.0) -> Bool {
        let futureTimeout = DispatchTime(uptimeNanoseconds: UInt64(timeout * 1000000000) + DispatchTime.now().uptimeNanoseconds)
        
        while (count > values.count) {
            if valueSemaphore.wait(timeout: futureTimeout) == .timedOut {
                return false
            }
        }
        
        return true
    }
    
    private func addValue(_ value: T) {
        values.append(value)
        
        valueSemaphore.signal()
    }
    
    private func addError(_ error: Error) {
        errors.append(error)
        
        errorSemaphore.signal()
    }
    
    public func on(_ event: Event<T>) {
        switch event {
        case .next(let element):
            addValue(element)
        case .error(let error):
            addError(error)
            break
        case .completed:
            break
        }
    }
}

extension Observable {
    func test(disposeBag: DisposeBag = DisposeBag()) -> TestObserver<E> {
        let observer = TestObserver<E>()
        
        self.subscribe(observer).disposed(by: disposeBag)
        
        return observer
    }
}

class IndexedObservableListTest: QuickSpec {
    override func spec() {
        describe("indexed list") {
            var disposeBag = DisposeBag()
            let inputList = SimpleObservableList<Int>()
            let indexedList = inputList.indexedMap { value, previous, next -> Observable<String> in
                return Observable.combineLatest([previous, next]).map { adjacent -> String in
                    let previous = String(adjacent[0] ?? -1)
                    let next = String(adjacent[1] ?? -1)
                    
                    return previous + " < " + String(value) + " > " + next
                }
            }
            
            beforeEach {
                inputList.removeAll()
                disposeBag = DisposeBag()
            }
            
            it("flat mapping") {
                let subject = PublishSubject<Int>()
                let mappedList = subject.asSingle().flatMapList { value -> ObservableList<Observable<String>> in
                    inputList.append(12)
                    
                    return indexedList
                }
                let test = mappedList.updates.test(disposeBag: disposeBag)
                
                assert(test.values.isEmpty)
                
                subject.onNext(1)
                subject.onCompleted()
                
                assert(test.awaitCount(1))
                
                let list = test.values[0].list
                
                expect(list.count) == 1
                
                expect(try? list[0].toBlocking().first()) == "-1 < 12 > -1"
            }
            
            it("supports single items") {
                inputList.append(1)
                
                let test = indexedList.updates.test(disposeBag: disposeBag)

                assert(test.awaitCount(1))
                
                let list = test.values[0].list
                
                expect(list.count) == 1
                
                expect(try? list[0].toBlocking().first()) == "-1 < 1 > -1"
            }
            
            it("supports 3 item list") {
                inputList.append(1)
                inputList.append(2)
                inputList.append(3)
                
                let test = indexedList.updates.test(disposeBag: disposeBag)
                
                assert(test.awaitCount(1))
                
                let list = test.values[0].list
                
                expect(list.count) == 3
                
                expect(try? list[0].toBlocking().first()) == "-1 < 1 > 2"
                expect(try? list[1].toBlocking().first()) == "1 < 2 > 3"
                expect(try? list[2].toBlocking().first()) == "2 < 3 > -1"
            }
            
            it("supports changing lists") {
                // 101
                inputList.append(101)
                
                // 101, 102
                inputList.append(102)
                
                // 101, 102, 103
                inputList.append(103)
                
                let test = indexedList.updates.test(disposeBag: disposeBag)
                
                assert(test.awaitCount(1))
                
                let list = test.values[0].list
                
                expect(list.count) == 3
                
                let item0 = list[0].test(disposeBag: disposeBag) // 101 @ 0
                let item1 = list[1].test(disposeBag: disposeBag) // 102 @ 1
                let item2 = list[2].test(disposeBag: disposeBag) // 103 @ 2
                
                expect(item0.values[0]) == "-1 < 101 > 102"
                expect(item1.values[0]) == "101 < 102 > 103"
                expect(item2.values[0]) == "102 < 103 > -1"
                
                // 101, 104, 102, 103
                inputList.insert(104, at: 1)
                
                assert(test.awaitCount(2))
                
                let nextList = test.values[1].list
                
                let item3 = nextList[1].test(disposeBag: disposeBag)
                
                expect(item0.values.last) == "-1 < 101 > 104" // 101 @ 0
                expect(item3.values.last) == "101 < 104 > 102" // 104 @ 1
                expect(item1.values.last) == "104 < 102 > 103" // 102 @ 2
                expect(item2.values.last) == "102 < 103 > -1" // 103 @ 3
                
                // 101, 104, 103
                inputList.remove(at: 2)
                
                assert(test.awaitCount(3))
                
                expect(item0.values.last) == "-1 < 101 > 104" // 101 @ 0
                expect(item3.values.last) == "101 < 104 > 103" // 104 @ 1
                expect(item2.values.last) == "104 < 103 > -1" // 103 @ 2
            }
        }
    }
}
