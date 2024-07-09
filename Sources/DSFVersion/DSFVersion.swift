//
//  DSFVersion.swift
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

import Foundation

/// A simple version class supporting major, (optional) minor, (optional) patch and (optional) build integer values.
public struct Version: CustomDebugStringConvertible {
	/// Helper constant for wildcard support
	public static let Wildcard: Int = -1

	/// Errors thrown during parsing
	public enum VersionError: Error {
		/// Tried to parse a version from a string and it was incompatible.
		case InvalidVersionString
		/// Attempted to increment a version object but the version was wildcarded (eg. 6.5.*)
		case CannotIncrementWildcard
	}

	/// An enum publicly identifying the fields within the version
	public enum Field {
		/// The major field
		case major
		/// The minor field
		case minor
		/// The patch field
		case patch
		/// The build field
		case build
	}

	// Regular Expression definition
	private static let RegexpString = #"^(?:(\d+)\.)?(?:(\d+)\.)?(?:(\d+)\.)?(\*|\d+)$"#
	private static let Regex = try! NSRegularExpression(pattern: RegexpString, options: [])

	/// Major field in the version (major.-.-.-)
	public private(set) var major: FieldValue
	/// Minor field in the version (-.minor.-.-)
	public private(set) var minor: FieldValue
	/// Patch field in the version (-.-.patch.-)
	public private(set) var patch: FieldValue
	/// Build field in the version (-.-.-.build)
	public private(set) var build: FieldValue

	/// Does the version contain a wildcard (for example, 10.4.* == true, 10.4.3 == false)
	@inlinable public var hasWildcard: Bool {
		self.major.isWildcard || self.minor.isWildcard || self.patch.isWildcard || self.build.isWildcard
	}

	/// Return a string representation of the version (eg. "10.5.*")
	public var stringValue: String {
		var result = self.major.stringValue
		if self.minor != .unassigned {
			result += "." + self.minor.stringValue
		}
		if self.patch != .unassigned {
			result += "." + self.patch.stringValue
		}
		if self.build != .unassigned {
			result += "." + self.build.stringValue
		}
		return result
	}

	public var debugDescription: String {
		return self.stringValue
	}

	/// Create a new version object
	/// - Parameters:
	///   - major: The major version number
	///   - minor: The minor version number
	///   - patch: The patch version number
	///   - build: The build version number
	public init(
		_ major: FieldValue,
		_ minor: FieldValue = .unassigned,
		_ patch: FieldValue = .unassigned,
		_ build: FieldValue = .unassigned
	) {
		self.major = major
		self.minor = minor
		self.patch = patch
		self.build = build

		self.sanitize()
	}

	/// Create a new version object
	/// - Parameters:
	///   - major: The major version number.
	///   - minor: The minor version number.
	///   - patch: The patch version number.
	///   - build: The build version number.
	///
	///   Notes:
	///     * Use `Version.Wildcard` for a wildcard value (\*)
	///     * Use `nil` for a unassigned field (default)
	public init(_ major: Int? = nil, _ minor: Int? = nil, _ patch: Int? = nil, _ build: Int? = nil) {
		self.init(FieldValue.map(major), FieldValue.map(minor), FieldValue.map(patch), FieldValue.map(build))
	}

	/// Create a Version object from a string representation
	/// - Parameters:
	///   - versionString: the string to parse
	/// - Throws: `VersionError.InvalidVersionString` if the string cannot be parsed
	public init(_ versionString: String) throws {
		self = try Self.TryParse(versionString)
	}
}

private extension Version {
	mutating func sanitize() {
		if self.major.isWildcard {
			self.minor = .unassigned
			self.patch = .unassigned
			self.build = .unassigned
		}
		else if self.minor.isWildcard || self.minor.isUnassigned {
			self.patch = .unassigned
			self.build = .unassigned
		}
		else if self.patch.isWildcard || self.patch.isUnassigned {
			self.build = .unassigned
		}
	}
}

// MARK: - Field Value

public extension Version {
	/// A version field value`
	enum FieldValue: Equatable, CustomDebugStringConvertible {
		/// A field value
		case value(Int)
		/// A wildcard value
		case wildcard
		/// The field is unassigned
		case unassigned

		/// String representation of the field
		public var stringValue: String {
			switch self {
			case .unassigned: return ""
			case .wildcard: return "*"
			case .value(let value): return "\(value)"
			}
		}

		/// String representation of the field
		public var debugDescription: String { self.stringValue }

		var intValue: Int {
			switch self {
			case .unassigned: return 0
			case .wildcard: return -1
			case .value(let value): return value
			}
		}

		/// Map from an integer value to a field value
		static func map(_ v: Int?) -> FieldValue {
			guard let v = v else { return .unassigned }
			if v == Version.Wildcard { return .wildcard }
			return .value(v)
		}

		/// Does this field contain a value?
		var isSpecified: Bool { self != .unassigned }

		/// Is this field unassigned?
		public var isUnassigned: Bool { self == .unassigned }

		/// Is this field a wildcard?
		public var isWildcard: Bool { self == .wildcard }
	}
}

public extension Version {
	/// Try to parse a DSFVersion object from the provided string.
	/// - Parameters:
	///   - versionString: the string to parse
	/// - Returns: A new version object from the parsed version string
	/// - Throws: `VersionError.InvalidVersionString` if the version string cannot be parsed
	static func TryParse(_ versionString: String) throws -> Version {
		// Trim off any whitespace at the start and end of the version string
		let vstring = versionString.trimmingCharacters(in: .whitespaces)

		// Grab the regex match. We're expecting the match to be EXACTLY the same size as the trimmed string
		let nsrange = NSRange(vstring.startIndex ..< vstring.endIndex, in: vstring)

		guard
			let match = Version.Regex.firstMatch(in: vstring, options: [], range: nsrange),
			match.range == nsrange
		else {
			throw VersionError.InvalidVersionString
		}

		assert(match.range == nsrange)

		var hasWildcard = false
		var fields: [FieldValue] = []
		try (1 ..< match.numberOfRanges).forEach { index in

			guard let r = Range(match.range(at: index), in: vstring) else {
				return
			}

			let s = String(vstring[r])
			if s == "*" {
				if hasWildcard {
					// Multiple wildcards encountered
					throw VersionError.InvalidVersionString
				}
				fields.append(.wildcard)
				hasWildcard = true
			}
			else {
				guard let value = Int(s) else {
					// This is impossible to hit given the regex definition
					throw VersionError.InvalidVersionString
				}
				fields.append(.value(value))
			}
		}

		// Pad to end with empty fields
		(fields.count ..< 4).forEach { _ in
			fields.append(.unassigned)
		}

		return Version(fields[0], fields[1], fields[2], fields[3])
	}
}

// MARK: - Equalities

extension Version: Equatable, Comparable {
	/// Comparison result
	public enum ComparisonResult {
		case ascending
		case same
		case descending
		case error
	}

	/// Compare two Version objects.
	/// - Parameters:
	///   - lhs: left version object
	///   - rhs: right version object
	/// - Returns: Returns an ComparisonResult value that indicates the lexical ordering of a specified range within the two versions
	///
	/// The LHS value cannot contain wildcards, and will return `.error` if it contains one
	public static func compare(lhs: Self, rhs: Self) -> Version.ComparisonResult {
		// Left hand side cannot contain a wildcard range
		if lhs.hasWildcard { return .error }

		// Major check
		if lhs.major.intValue < rhs.major.intValue { return .ascending }
		if lhs.major.intValue > rhs.major.intValue { return .descending }

		// Minor check

		if lhs.minor.intValue < rhs.minor.intValue { return .ascending }
		if lhs.minor.intValue > rhs.minor.intValue { return .descending }

		// Patch check

		if lhs.patch.intValue < rhs.patch.intValue { return .ascending }
		if lhs.patch.intValue > rhs.patch.intValue { return .descending }

		// Build check

		if lhs.build.intValue < rhs.build.intValue { return .ascending }
		if lhs.build.intValue > rhs.build.intValue { return .descending }

		// Values are equal
		return .same
	}

	/// Perform an equality check between two version objects
	/// - Parameters:
	///   - lhs: left version
	///   - rhs: right version
	/// - Returns: true if the two versions are equal, false otherwise
	///
	///   When dealing with wildcards, a * matches against either size of the comparison
	///
	///   So, `2.* == 2.3` is equivalent to `2.3 == 2.*`
	public static func == (lhs: Self, rhs: Self) -> Bool {
		// Major

		if lhs.major == .wildcard { return true } //  v* == v4
		if rhs.major == .wildcard { return true } //  v4 == v*
		if lhs.major != rhs.major { return false } //  v4 != v5

		// Minor

		if lhs.minor == .wildcard { return true } //  v4.* == v4.1
		if rhs.minor == .wildcard { return true } //  v4.3 == v4.*
		if lhs.minor != rhs.minor { return false } //  v4.5 != v4.0

		// Patch

		if lhs.patch == .wildcard { return true } //  v4.4.* == v4.4.1
		if rhs.patch == .wildcard { return true } //  v4.3.2 == v4.3.*
		if lhs.patch != rhs.patch { return false } //  v4.5.4 != v4.5.2

		// Build

		if lhs.build == .wildcard { return true } //  v4.4.5.* == v4.4.1
		if rhs.build == .wildcard { return true } //  v4.3.2 == v4.3.*
		if lhs.build != rhs.build { return false } //  v4.5.4 != v4.5.2

		return true
	}

	/// If this version object has a wildcard, returns true if 'version' is contained in its range
	///
	/// For example,
	///
	///      `4.4.*` contains `4.4.5.1000`
	///      `4.4.*` does not contain `4.5.0.1001` or `4.2.3`
	public func contains(_ version: Version) -> Bool {
		// Cannot compare if a version being compared against contains a range
		if version.hasWildcard == true { return false }

		if self.major == .wildcard { return true }       //  v* == v4
		if self.major != version.major { return false }  //  v4 != v5

		if self.minor == .wildcard { return true }       //  v2.* == v2.4
		if self.minor != version.minor { return false }  //  v2.2 != v2.4

		if self.patch == .wildcard { return true }       //  v2.4.* == v2.4.5
		if self.patch != version.patch { return false }  //  v2.4.3 != v2.4.6

		if self.build == .wildcard { return true }       //  v2.4.5.* == v2.4.5.111
		if self.build != version.build { return false }  //  v2.4.5.201 != v2.4.5.111

		// A perfect match (ie. 1.2.3.4 == 1.2.3.4).  As such it contains it!
		return true
	}

	@inlinable public static func > (lhs: Self, rhs: Self) -> Bool {
		// Left hand side cannot contain a wildcard range
		return Version.compare(lhs: lhs, rhs: rhs) == .descending
	}

	@inlinable public static func < (lhs: Self, rhs: Self) -> Bool {
		return Version.compare(lhs: lhs, rhs: rhs) == .ascending
	}

	@inlinable public static func >= (lhs: Self, rhs: Self) -> Bool {
		let result = Version.compare(lhs: lhs, rhs: rhs)
		return result == .descending || result == .same
	}

	@inlinable public static func <= (lhs: Self, rhs: Self) -> Bool {
		let result = Version.compare(lhs: lhs, rhs: rhs)
		return result == .ascending || result == .same
	}

	@inlinable public static func != (lhs: Self, rhs: Self) -> Bool {
		return Version.compare(lhs: lhs, rhs: rhs) != .same
	}
}

// MARK: - Increment support

public extension Version {
	/// Return a new Version by Incrementing a field number, optionally zeroing all fields of lesser significance
	/// - Parameters:
	///   - field: The field to increment
	///   - zeroLower: if true, zeroes all lesser significant fields  (eg. 10.4.3.1000 --> 10.5.0.0)
	/// - Returns: A new DSFVersion object.
	/// - Throws: `CannotIncrementWildcard` if the version object contains a wildcard (eg. 10.4.3.*)*
	func incrementing(_ field: Field, zeroLower: Bool = true) throws -> Version {
		guard self.hasWildcard == false else { throw VersionError.CannotIncrementWildcard }

		switch field {
		case .major:
			return Version(
				.value(self.major.intValue + 1),
				zeroLower ? .unassigned : .value(self.minor.intValue),
				zeroLower ? .unassigned : .value(self.patch.intValue),
				zeroLower ? .unassigned : .value(self.build.intValue)
			)
		case .minor:
			return Version(
				.value(self.major.intValue),
				.value(self.minor.intValue + 1),
				zeroLower ? .unassigned : .value(self.patch.intValue),
				zeroLower ? .unassigned : .value(self.build.intValue)
			)
		case .patch:
			return Version(
				.value(self.major.intValue),
				.value(self.minor.intValue),
				.value(self.patch.intValue + 1),
				zeroLower ? .unassigned : .value(self.build.intValue)
			)
		case .build:
			return Version(
				.value(self.major.intValue),
				.value(self.minor.intValue),
				.value(self.patch.intValue),
				.value(self.build.intValue + 1)
			)
		}
	}
}

// MARK: - Codable support

extension Version: Codable {
	public init(from decoder: Decoder) throws {
		let values = try decoder.singleValueContainer()
		let value = try values.decode(String.self)
		try self.init(value)
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(self.stringValue)
	}
}
