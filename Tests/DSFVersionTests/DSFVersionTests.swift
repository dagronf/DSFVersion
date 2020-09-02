//
//  DSFVersionTests.swift
//
//  Created by Darren Ford on 2/9/2020.
//
//  MIT license
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
//  documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial
//  portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
//  WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
//  OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
//  OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

@testable import DSFVersion
import XCTest

final class DSFVersionTests: XCTestCase {
	func testSimple() throws {
		let v1 = DSFVersion(1)
		XCTAssertTrue(v1.major.isSpecified)
		XCTAssertFalse(v1.minor.isSpecified)
		XCTAssertFalse(v1.patch.isSpecified)
		XCTAssertFalse(v1.build.isSpecified)
		XCTAssertEqual(v1.major.value, 1)

		let v2 = DSFVersion(DSFVersion.Wildcard)
		XCTAssertTrue(v2.major.isWildcard)
		XCTAssertTrue(v2.major.isSpecified)
		XCTAssertFalse(v2.minor.isSpecified)
		XCTAssertFalse(v2.patch.isSpecified)
		XCTAssertFalse(v2.build.isSpecified)

		let v3 = DSFVersion(15, DSFVersion.Wildcard)
		XCTAssertFalse(v3.major.isWildcard)
		XCTAssertTrue(v3.major.isSpecified)
		XCTAssertEqual(v3.major.value, 15)

		XCTAssertTrue(v3.minor.isWildcard)
		XCTAssertTrue(v3.minor.isSpecified)

		let v4 = try DSFVersion("15.3.4")
		XCTAssertEqual(DSFVersion(15, 3, 4), v4)
		XCTAssertEqual(v4.stringValue, "15.3.4")

		let v8 = try DSFVersion("15.3.4.*")
		XCTAssertEqual(v8.stringValue, "15.3.4.*")

		XCTAssertNotEqual(DSFVersion(15), v4)
		XCTAssertNotEqual(DSFVersion(15, 3), v4)
		XCTAssertNotEqual(DSFVersion(15, 3, 4, 10001), v4)

		let v5 = DSFVersion.TryParse("99.8.*")
		XCTAssertNotNil(v5)
		let v6 = DSFVersion.TryParse("99.8..*")
		XCTAssertNil(v6)
	}

	func testParse() throws {
		XCTAssertThrowsError(try DSFVersion("macOS 10.2.2"))
		XCTAssertThrowsError(try DSFVersion("cat"))
		XCTAssertThrowsError(try DSFVersion("1,2,3,4"))
		let v2 = try DSFVersion("1.2.3.*")
		let v333 = try XCTUnwrap(v2)
		XCTAssert(v333.major.value == 1)
		XCTAssertNoThrow(try DSFVersion("1.*"))
		XCTAssertNoThrow(try DSFVersion("1"))
		XCTAssertThrowsError(try DSFVersion("1."))
		XCTAssertThrowsError(try DSFVersion(".2.3.4"))
		XCTAssertThrowsError(try DSFVersion("1.2.a.4"))
	}

	func testEquality() throws {
		let v0 = try DSFVersion("10.4.4")
		let v1 = try DSFVersion("10.4")

		XCTAssertEqual(v0, v0)
		XCTAssertEqual(v1, v1)
		XCTAssertNotEqual(v0, v1)

		XCTAssertTrue(v0 >= v1)
		XCTAssertFalse(v1 >= v0)
	}

	func testIsCompatible() throws {
		let v0 = try DSFVersion("10.4.4")
		let v1 = try DSFVersion("10.4")

		XCTAssertTrue(v0 >= v1)

		let v2 = try DSFVersion("4.4.5")
		let v3 = try DSFVersion("4.4.*")
		XCTAssertTrue(v2 >= v3)

		XCTAssertEqual(v2, v3)
		XCTAssertEqual(v3, v2)

		//  v2 is a fixed DSFVersion, v3 is a range.  Comparison should fail
		XCTAssertFalse(v2.contains(v3))

		//  v3 'range' (4.4.*) includes v3 (4.4.5)
		XCTAssertTrue(v3.contains(v2))

		// FAIL: v3 contains a wildcard -- cannot compare
		XCTAssertFalse(v3 >= v2)

		// SUCCESS: 4.4.5 is contained within the range 4.*
		XCTAssertEqual(v2, try DSFVersion("4.*"))

		let v445 = DSFVersion(4, 4, 5, -1) // 4.4.5.*
		XCTAssertTrue(DSFVersion(4, 4, 5) >= v445) // 4.4.5 is contained within v445
		XCTAssertTrue(DSFVersion(4, 4, 5, 0) >= v445) // 4.4.5.0 is contained within v445
		XCTAssertTrue(DSFVersion(4, 4, 5, 999) >= v445) // 4.4.5.999 is contained within v445

		XCTAssertTrue(DSFVersion(4, 4, -1).contains(DSFVersion(4, 4, 5, 999))) // 4.4.* contains 4.4.5.999

		XCTAssertTrue(DSFVersion(4, 4, -1).contains(DSFVersion(4, 5, 5, 999))) // 4.4.* contains 4.5.5.999
		XCTAssertFalse(DSFVersion(4, 4, -1).contains(DSFVersion(4, 3, 5, 999))) // 4.4.* does not contain 4.3.5.999

		// Cannot check with a wildcard on the left hand side
		XCTAssertFalse(DSFVersion(14,5,0,-1) > DSFVersion(14,5,0,1000))
		XCTAssertFalse(DSFVersion(14,5,0,-1) < DSFVersion(14,5,0,1000))

		XCTAssertGreaterThan(DSFVersion(14,5,0), DSFVersion(14,5,-1))	// 14.5.0 > 14.5.*

	}

	func testClosedRangeThrough() throws {
		// A closed range between v4 and v5 (inclusive)

		let range = DSFVersion(4)...DSFVersion(5)

		let v2 = try DSFVersion("4.4.5")

		XCTAssertTrue(range.contains(v2))
		XCTAssertFalse(range.contains(DSFVersion(3, 9, 9, 9999)))
		XCTAssertTrue(range.contains(try DSFVersion("4.0.0.0")))
		XCTAssertTrue(range.contains(try DSFVersion("5.0.0.0")))
		XCTAssertFalse(range.contains(try DSFVersion("5.0.1")))

		XCTAssertTrue(range.contains(DSFVersion(4)))
		XCTAssertTrue(range.contains(DSFVersion(5)))

		// Check the Range using Swift range comparison

		let range2 = DSFVersion(1,0) ... DSFVersion(1,2)
		XCTAssertTrue(range2.contains(DSFVersion(1,1)))
		XCTAssertTrue(range2.contains(DSFVersion(1,0,0,0)))
		XCTAssertTrue(range2.contains(DSFVersion(1,2)))
		XCTAssertTrue(range2.contains(DSFVersion(1,2,0,0)))
		XCTAssertFalse(range2.contains(DSFVersion(1,2,0,1)))
	}

	func testClosedRangeUpTo() throws {
		// A closed range between v4 and v5 (not including v5)

		let rangeUpTo = DSFVersion(4)..<DSFVersion(5)

		let v2 = try DSFVersion("4.4.5")

		XCTAssertTrue(rangeUpTo.contains(v2))
		XCTAssertFalse(rangeUpTo.contains(try DSFVersion("3.9.9.9999")))

		XCTAssertTrue(rangeUpTo.contains(try DSFVersion("4.0.0.0")))
		XCTAssertTrue(rangeUpTo.contains(try DSFVersion("4.9.9.9999")))

		XCTAssertFalse(rangeUpTo.contains(try DSFVersion("5")))
		XCTAssertFalse(rangeUpTo.contains(try DSFVersion("5.0.0.0")))
		XCTAssertFalse(rangeUpTo.contains(try DSFVersion("5.0.1")))

		XCTAssertTrue(rangeUpTo.contains(DSFVersion(4)))
		XCTAssertFalse(rangeUpTo.contains(DSFVersion(5)))

		// Check the Range using Swift range comparison

		let range = DSFVersion(1,0) ..< DSFVersion(1,2)
		XCTAssertTrue(range.contains(DSFVersion(1,1)))
		XCTAssertTrue(range.contains(DSFVersion(1,0,0,0)))
		XCTAssertFalse(range.contains(DSFVersion(1,2)))
	}

	func testPartialRanges() {
		// Partial range check
		let r3 = DSFVersion(1,2)...
		XCTAssertTrue(r3.contains(DSFVersion(1,3)))
		XCTAssertTrue(r3.contains(DSFVersion(3,2,15,6)))
		XCTAssertFalse(r3.contains(DSFVersion(1,1)))

		let r4 = ..<DSFVersion(14,5,7)
		XCTAssertTrue(r4.contains(DSFVersion(1)))
		XCTAssertTrue(r4.contains(DSFVersion(14,5,6)))
		XCTAssertFalse(r4.contains(DSFVersion(14,5,7)))

		let r5 = ...DSFVersion(14,5,7)
		XCTAssertTrue(r5.contains(DSFVersion(14,5,7)))
		XCTAssertFalse(r5.contains(DSFVersion(14,5,7,1)))
	}

	func testCodable() throws {
		let v1 = DSFVersion(10, 4, 3)
		let data = try JSONEncoder().encode(v1)

		let str = String(data: data, encoding: .utf8)
		XCTAssertEqual(#""10.4.3""#, str)

		let v1rec = try JSONDecoder().decode(DSFVersion.self, from: data)
		XCTAssertEqual(v1, v1rec)

		///

		let v2 = DSFVersion(55, -1)
		let data2 = try JSONEncoder().encode(v2)
		let v2rec = try JSONDecoder().decode(DSFVersion.self, from: data2)
		XCTAssertEqual(v2, v2rec)

		let str2 = String(data: data2, encoding: .utf8)
		XCTAssertEqual(#""55.*""#, str2)

		struct TestValue: Codable, Equatable {
			let iVal: Int
			let DSFVersion: DSFVersion
			init(iVal: Int, DSFVersion: DSFVersion) {
				self.iVal = iVal
				self.DSFVersion = DSFVersion
			}
		}

		let v3 = TestValue(iVal: 3, DSFVersion: DSFVersion(3, 6, DSFVersion.Wildcard))
		let data3 = try JSONEncoder().encode(v3)

		let str3 = String(data: data3, encoding: .utf8)
		XCTAssertEqual(#"{"DSFVersion":"3.6.*","iVal":3}"#, str3)

		let v3rec = try JSONDecoder().decode(TestValue.self, from: data3)
		XCTAssertEqual(v3, v3rec)
	}

	func testDocoExample() throws {
		let lowerBound = DSFVersion(10,4)
		let upperBound = DSFVersion(10,5)

		XCTAssertLessThan(lowerBound, upperBound)

		// Read from somewhere, and try to convert to a version definition
		let strVer = "10.4.5"
		let myVersion = try DSFVersion(strVer)   // Throws if strVer isn't a version

		// Simple comparison to verify if our read version is greater than our lower bound
		XCTAssertLessThan(lowerBound, myVersion)

		// See whether the version we read was without our required range
		let range = lowerBound ..< upperBound
		assert(range.contains(myVersion))

		let range2 = lowerBound ..< lowerBound
	}

	static var allTests = [
		("testSimple", testSimple),
		("testParse", testParse),
		("testEquality", testEquality),
		("testIsCompatible", testIsCompatible),
		("testClosedRangeThrough", testClosedRangeThrough),
		("testClosedRangeUpTo", testClosedRangeUpTo),
		("testCodable", testCodable),
	]
}
