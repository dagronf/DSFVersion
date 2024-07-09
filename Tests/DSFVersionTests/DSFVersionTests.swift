//
//  VersionTests.swift
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

final class VersionTests: XCTestCase {
	func testSimple() throws {
		performTest {
			let v1 = Version(1)
			XCTAssertTrue(v1.major.isAssigned)
			XCTAssertFalse(v1.minor.isAssigned)
			XCTAssertFalse(v1.patch.isAssigned)
			XCTAssertFalse(v1.build.isAssigned)
			XCTAssertEqual(v1.major.intValue, 1)

			let v2 = Version(.wildcard)
			XCTAssertTrue(v2.major == .wildcard)
			XCTAssertTrue(v2.major.isAssigned)
			XCTAssertFalse(v2.minor.isAssigned)
			XCTAssertFalse(v2.patch.isAssigned)
			XCTAssertFalse(v2.build.isAssigned)

			let v3 = Version(15, .wildcard)
			XCTAssertFalse(v3.major == .wildcard)
			XCTAssertTrue(v3.major.isAssigned)
			XCTAssertEqual(v3.major.intValue, 15)

			XCTAssertTrue(v3.minor == .wildcard)
			XCTAssertTrue(v3.minor.isAssigned)

			let v4 = try Version("15.3.4")
			XCTAssertEqual(Version(15, 3, 4), v4)
			XCTAssertEqual(v4.stringValue, "15.3.4")

			let v8 = try Version("15.3.4.*")
			XCTAssertEqual(v8.stringValue, "15.3.4.*")

			XCTAssertNotEqual(Version(15), v4)
			XCTAssertNotEqual(Version(15, 3), v4)
			XCTAssertNotEqual(Version(15, 3, 4, 10001), v4)

			let v5 = try XCTUnwrap(try? Version.TryParse("99.8.*"))
			XCTAssertNotNil(v5)

			// Make sure all field formats correct
			XCTAssertNoThrow(try Version.TryParse("1.2.3.4"))
			XCTAssertNoThrow(try Version.TryParse("1.2.3.*"))
			XCTAssertNoThrow(try Version.TryParse("1.2.*"))
			XCTAssertNoThrow(try Version.TryParse("1.*"))
			XCTAssertNoThrow(try Version.TryParse("*"))                // Odd, but valid
			XCTAssertThrowsError(try Version.TryParse("1.0.0.0.*"))    // too many fields

			// check for an invalid string
			XCTAssertThrowsError(try Version.TryParse("99.8..*"))
			XCTAssertThrowsError(try Version.TryParse("A.B.C.D"))
			XCTAssertThrowsError(try Version.TryParse("1.2.3.D"))
			XCTAssertThrowsError(try Version.TryParse("🐼.2.3"))       // non-digits character
			XCTAssertThrowsError(try Version.TryParse("1.*.*"))        // multiple wildcards

		}
	}

	func testParse() throws {
		XCTAssertThrowsError(try Version("macOS 10.2.2"))
		XCTAssertThrowsError(try Version("cat"))
		XCTAssertThrowsError(try Version("1,2,3,4"))
		let v2 = try Version("1.2.3.*")
		let v333 = try XCTUnwrap(v2)
		XCTAssert(v333.major.intValue == 1)
		XCTAssertNoThrow(try Version("1.*"))
		XCTAssertNoThrow(try Version("1"))
		XCTAssertThrowsError(try Version("1."))
		XCTAssertThrowsError(try Version(".2.3.4"))
		XCTAssertThrowsError(try Version("1.2.a.4"))

		// With whitespace at start and end
		let t1 = try Version("1.2 ")
		XCTAssertEqual(Version(1, 2), t1)
		let t2 = try Version("     1.2")
		XCTAssertEqual(Version(1, 2), t2)
		let t3 = try Version("     1.2    ")
		XCTAssertEqual(Version(1, 2), t3)
	}

	func testEquality() throws {
		let v0 = try Version("10.4.4")
		let v1 = try Version("10.4")

		XCTAssertEqual(v0, v0)
		XCTAssertEqual(v1, v1)
		XCTAssertNotEqual(v0, v1)

		XCTAssertTrue(v0 >= v1)
		XCTAssertFalse(v1 >= v0)
	}

	func testIsCompatible() throws {
		let v0 = try Version("10.4.4")
		let v1 = try Version("10.4")

		XCTAssertTrue(v0 >= v1)

		let v2 = try Version("4.4.5")
		let v3 = try Version("4.4.*")
		XCTAssertTrue(v2 >= v3)

		XCTAssertEqual(v2, v3)
		XCTAssertEqual(v3, v2)

		let v7 = Version(5, 99)
		let v8 = Version(4, 4, 1)
		XCTAssertFalse(v3.contains(v7))
		XCTAssertTrue(v3.contains(v8))

		//  v2 is a fixed Version, v3 is a range.  Comparison should fail
		XCTAssertFalse(v2.contains(v3))

		//  v3 'range' (4.4.*) includes v3 (4.4.5)
		XCTAssertTrue(v3.contains(v2))

		// FAIL: v3 contains a wildcard -- cannot compare
		XCTAssertFalse(v3 >= v2)

		// SUCCESS: 4.4.5 is contained within the range 4.*
		XCTAssertEqual(v2, try Version("4.*"))

		let v445 = Version(4, 4, 5, .wildcard) // 4.4.5.*
		XCTAssertTrue(Version(4, 4, 5) >= v445) // 4.4.5 is contained within v445
		XCTAssertTrue(Version(4, 4, 5, 0) >= v445) // 4.4.5.0 is contained within v445
		XCTAssertTrue(Version(4, 4, 5, 999) >= v445) // 4.4.5.999 is contained within v445

		XCTAssertTrue(Version(4, 4, .wildcard).contains(Version(4, 4, 5, 999))) // 4.4.* contains 4.4.5.999

		XCTAssertFalse(Version(4, 4, .wildcard).contains(Version(4, 5, 5, 999))) // 4.4.* does not contain 4.5.5.999
		XCTAssertFalse(Version(4, 4, .wildcard).contains(Version(4, 3, 5, 999))) // 4.4.* does not contain 4.3.5.999

		XCTAssertTrue(Version(4, 5, 5, 999) >= Version(4, 4, .wildcard))

		// Cannot check with a wildcard on the left hand side
		XCTAssertFalse(Version(14, 5, 0, .wildcard) > Version(14, 5, 0, 1000))
		XCTAssertFalse(Version(14, 5, 0, .wildcard) < Version(14, 5, 0, 1000))

		XCTAssertGreaterThan(Version(14, 5, 0), Version(14, 5, .wildcard)) // 14.5.0 > 14.5.*
	}

	func testClosedRangeThrough() throws {
		// A closed range between v4 and v5 (inclusive)

		let range = Version(4) ... Version(5)

		let v2 = try Version("4.4.5")

		XCTAssertTrue(range.contains(v2))
		XCTAssertFalse(range.contains(Version(3, 9, 9, 9999)))
		XCTAssertTrue(range.contains(try Version("4.0.0.0")))
		XCTAssertTrue(range.contains(try Version("5.0.0.0")))
		XCTAssertFalse(range.contains(try Version("5.0.1")))

		XCTAssertTrue(range.contains(Version(4)))
		XCTAssertTrue(range.contains(Version(5)))

		// Check the Range using Swift range comparison

		let range2 = Version(1, 0) ... Version(1, 2)
		XCTAssertTrue(range2.contains(Version(1, 1)))
		XCTAssertTrue(range2.contains(Version(1, 0, 0, 0)))
		XCTAssertTrue(range2.contains(Version(1, 2)))
		XCTAssertTrue(range2.contains(Version(1, 2, 0, 0)))
		XCTAssertFalse(range2.contains(Version(1, 2, 0, 1)))
	}

	func testClosedRangeUpTo() throws {
		// A closed range between v4 and v5 (not including v5)

		let rangeUpTo = Version(4) ..< Version(5)

		let v2 = try Version("4.4.5")

		XCTAssertTrue(rangeUpTo.contains(v2))
		XCTAssertFalse(rangeUpTo.contains(try Version("3.9.9.9999")))

		XCTAssertTrue(rangeUpTo.contains(try Version("4.0.0.0")))
		XCTAssertTrue(rangeUpTo.contains(try Version("4.9.9.9999")))

		XCTAssertFalse(rangeUpTo.contains(try Version("5")))
		XCTAssertFalse(rangeUpTo.contains(try Version("5.0.0.0")))
		XCTAssertFalse(rangeUpTo.contains(try Version("5.0.1")))

		XCTAssertTrue(rangeUpTo.contains(Version(4)))
		XCTAssertFalse(rangeUpTo.contains(Version(5)))

		// Check the Range using Swift range comparison

		let range = Version(1, 0) ..< Version(1, 2)
		XCTAssertTrue(range.contains(Version(1, 1)))
		XCTAssertTrue(range.contains(Version(1, 0, 0, 0)))
		XCTAssertFalse(range.contains(Version(1, 2)))
	}

	func testPartialRanges() {
		// Partial range check
		let r3 = Version(1, 2)...
		XCTAssertTrue(r3.contains(Version(1, 3)))
		XCTAssertTrue(r3.contains(Version(3, 2, 15, 6)))
		XCTAssertFalse(r3.contains(Version(1, 1)))

		let r4 = ..<Version(14, 5, 7)
		XCTAssertTrue(r4.contains(Version(1)))
		XCTAssertTrue(r4.contains(Version(14, 5, 6)))
		XCTAssertFalse(r4.contains(Version(14, 5, 7)))

		let r5 = ...Version(14, 5, 7)
		XCTAssertTrue(r5.contains(Version(14, 5, 7)))
		XCTAssertFalse(r5.contains(Version(14, 5, 7, 1)))
	}

	func testCodable() throws {
		let v1 = Version(10, 4, 3)
		let data = try JSONEncoder().encode(v1)

		let str = String(data: data, encoding: .utf8)
		XCTAssertEqual(#""10.4.3""#, str)

		let v1rec = try JSONDecoder().decode(Version.self, from: data)
		XCTAssertEqual(v1, v1rec)

		///

		let v2 = Version(55, .wildcard)
		let data2 = try JSONEncoder().encode(v2)
		let v2rec = try JSONDecoder().decode(Version.self, from: data2)
		XCTAssertEqual(v2, v2rec)

		// Wildcard

		let str2 = String(data: data2, encoding: .utf8)
		XCTAssertEqual(#""55.*""#, str2)

		struct TestValue: Codable, Equatable {
			let version: Version
			let name: String
			let value: Int
			init(version: Version, name: String, value: Int) {
				self.version = version
				self.name = name
				self.value = value
			}
		}

		let v3 = TestValue(version: Version(3, 6, .wildcard), name: "counter", value: 3)
		let data3 = try JSONEncoder().encode(v3)

		let str3 = String(data: data3, encoding: .utf8)

		let ddd = try JSONDecoder().decode(TestValue.self, from: data3)
		XCTAssertEqual(v3, ddd)

		//XCTAssertEqual(#"{"version":"3.6.*","name":"counter","value":3}"#, str3)

		let v3rec = try JSONDecoder().decode(TestValue.self, from: data3)
		XCTAssertEqual(v3, v3rec)

		// Make sure that if a json has invalid version it throws an error as expected
		let invalidData1 = #"{"version":"3.A.*","name":"counter","value":3}"#.data(using: .utf8)!
		XCTAssertThrowsError(try JSONDecoder().decode(TestValue.self, from: invalidData1))
		let invalidData2 = #"{"version":"1.23.4.5.6","name":"counter","value":3}"#.data(using: .utf8)!
		XCTAssertThrowsError(try JSONDecoder().decode(TestValue.self, from: invalidData2))
		let invalidData3 = #"{"version":"3.A.*","name":"counter","value":3}"#.data(using: .utf8)!
		XCTAssertThrowsError(try JSONDecoder().decode(TestValue.self, from: invalidData3))

	}

	func testDocoExample() throws {
		let lowerBound = Version(10, 4)
		let upperBound = Version(10, 5)

		XCTAssertLessThan(lowerBound, upperBound)

		// Read from somewhere, and try to convert to a version definition
		let strVer = "10.4.5"
		let myVersion = try Version(strVer) // Throws if strVer isn't a version

		// Simple comparison to verify if our read version is greater than our lower bound
		XCTAssertLessThan(lowerBound, myVersion)

		// See whether the version we read was without our required range
		let range = lowerBound ..< upperBound
		assert(range.contains(myVersion))
	}

	func testIncrementer() throws {
		performTest {
			// Check that wildcard increment fails as expected
			XCTAssertThrowsError(try Version(10, 4, 3, .wildcard).incrementing(.minor))

			// Increment with zeroing
			let v1 = try Version(10, 4, 3, 1000).incrementing(.minor)
			XCTAssertEqual(v1, Version(10, 5))

			// Increment without zeroing
			let v2 = try XCTUnwrap(Version(10, 4, 3, 1000).incrementing(.minor, zeroLower: false))
			XCTAssertEqual(v2, Version(10, 5, 3, 1000))

			// Start with v1.2
			let vv12 = Version(1, 2)

			// Move to v1.2.0.1
			let vv1201 = try XCTUnwrap(try? vv12.incrementing(.build))
			XCTAssertEqual(vv1201, Version(1, 2, 0, 1))

			// Move from v1.2.0.1 -> v1.2.1
			let vv121 = try XCTUnwrap(try? vv1201.incrementing(.patch))
			XCTAssertEqual(vv121, Version(1, 2, 1))
			XCTAssertEqual("1.2.1", vv121.stringValue)

			// Move from v1.2.1 -> v1.3
			let vv13 = try XCTUnwrap(try? vv121.incrementing(.minor))
			XCTAssertEqual(vv13, Version(1, 3))

			// Move from v1.3 -> v2.0
			let vv2 = try XCTUnwrap(try? vv13.incrementing(.major))
			XCTAssertEqual(vv2, Version(2))

			XCTAssertEqual("2", vv2.stringValue)

			// Increment a field that was not initially specified
			XCTAssertEqual(Version(2, 0, 1), try Version(2).incrementing(.patch))
			XCTAssertEqual(Version(2, 4, 0, 1), try Version(2, 4).incrementing(.build))

		}
	}

	func testValidateSanitize() throws {
		XCTAssertEqual(Version(5, .wildcard, 3, 4), Version(5))
		XCTAssertEqual(Version(5, 6, .wildcard, 4), Version(5, 6, .wildcard))
	}
}
