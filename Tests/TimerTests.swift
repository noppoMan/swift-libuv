//
//  TimerTests.swift
//  Suv
//
//  Created by Yuki Takei on 2/19/16.
//  Copyright © 2016 MikeTOKYO. All rights reserved.
//

import XCTest
import Suv

class TimerTests: XCTestCase {
    
    func testTimerTimeout() {
        waitUntil(2, description: "Timer Timout") { done in
            let timer = Timer(mode: .Timeout, tick: 1000)
            XCTAssertEqual(timer.state, TimerState.Pause)

            let start = Time().unixtime
            
            timer.start {
                XCTAssertGreaterThan(Time().unixtime - start, 0)
                timer.end()
                XCTAssertEqual(timer.state, TimerState.End)
                Loop.defaultLoop.stop()
                done()
            }
            
            Loop.defaultLoop.run()
        }
    }
    
    func testTimerInterval() {
        waitUntil(5, description: "Timer Interval") { done in
            let timer = Timer(mode: .Interval, tick: 500)
            XCTAssertEqual(timer.state, TimerState.Pause)
            
            var intervalCounter = 0
            
            timer.start {
                XCTAssertEqual(timer.state, TimerState.Running)
                intervalCounter+=1
                if intervalCounter >= 3 {
                    timer.end()
                    XCTAssertEqual(timer.state, TimerState.End)
                    Loop.defaultLoop.stop()
                    done()
                }
            }
            
            sleep(1)
            timer.stop()
            
            sleep(2)
            XCTAssertEqual(timer.state, TimerState.Stop)
            timer.resume()
            XCTAssertEqual(timer.state, TimerState.Running)
            
            Loop.defaultLoop.run()
        }
    }
    
}
