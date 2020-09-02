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
public struct DSFVersion: CustomDebugStringConvertible {
	/// Errors thrown during parsing
	public enum VersionError: Error {
		/// Tried to parse a version from a string and it was incompatible.
		case InvalidVersionString
	}

	/// An enum identifying the fields within the version
	public enum Field {
		case major
		case minor
		case patch
		case build
	}

	/// Helper constant for wildcard support
	public static let Wildcard: Int32 = -1

	// Regular Expression definition
	private static let RegexpString = #"^(?:(\d+)\.)?(?:(\d+)\.)?(?:(\d+)\.)?(\*|\d+)$"#
	private static let Regex = try! NSRegularExpression(pattern: RegexpString, options: [])

	private let fields: [FieldValue]

	/// Major field in the version (major.-.-.-)
	public var major: FieldValue { return fields[0] }
	/// Minor field in the version (-.minor.-.-)
	public var minor: FieldValue { return fields[1] }
	/// Patch field in the version (-.-.patch.-)
	public var patch: FieldValue { return fields[2] }
	/// Build field in the version (-.-.-.build)
	public var build: FieldValue { return fields[3] }

	/// Does the version contain a wildcard (for example, 10.4.* == true, 10.4.3 == false)
	public var hasWildcard: Bool {
		return self.major.isWildcard
			|| self.minor.isWildcard
			|| self.patch.isWildcard
			|| self.build.isWildcard
	}

	/// Return a string representation of the version (eg. "10.5.*")
	public var stringValue: String {
		var result = self.major.debugDescription
		if self.minor.isSpecified {
			result += "." + self.minor.debugDescription
		}
		if self.patch.isSpecified {
			result += "." + self.patch.debugDescription
		}
		if self.build.isSpecified {
			result += "." + self.build.debugDescription
		}
		return result
	}

	public var debugDescription: String {
		return self.stringValue
	}

	/// Create a new version object
	/// - Parameters:
	///   - major: The major version number. Use -1 for a wildcard
	///   - minor: The minor version number. Use -1 for a wildcard, or nil for not specified
	///   - patch: The patch version number. Use -1 for a wildcard, or nil for not specified
	///   - build: The build version number. Use -1 for a wildcard, or nil for not specified
	init(_ major: Int32, _ minor: Int32? = nil, _ patch: Int32? = nil, _ build: Int32? = nil) {
		self.fields = [FieldValue(major), FieldValue(minor), FieldValue(patch), FieldValue(build)]
	}

	/// Try to create a DSFVersion object from the provided string.
	/// - Parameter versionString: the string to parse
	/// - Returns: A new version object if a version can be parsed from 'versionString', nil otherwise
	public static func TryParse(_ versionString: String) -> DSFVersion? {
		return try? DSFVersion(versionString)
	}

	/// Create a Version object from the provided string. Throws 'VersionError.InvalidVersionString
	/// - Parameter versionString: the string to parse
	/// - Throws: VersionError.InvalidVersionString if the string cannot be parsed
	init(_ versionString: String) throws {
		let nsrange = NSRange(versionString.startIndex ..< versionString.endIndex, in: versionString)

		guard let match = DSFVersion.Regex.firstMatch(in: versionString, options: [], range: nsrange) else {
			throw VersionError.InvalidVersionString
		}

		var fields = [FieldValue]()
		try (1 ..< match.numberOfRanges).forEach { index in

			guard let r = Range(match.range(at: index), in: versionString) else {
				return
			}

			let s = String(versionString[r])
			if s == "*" {
				fields.append(FieldValue.Wildcard)
			}
			else {
				guard let value = Int32(s) else {
					// This is impossible to hit given the regex definition
					throw VersionError.InvalidVersionString
				}
				fields.append(FieldValue(value))
			}
		}

		(fields.count ..< 4).forEach { _ in
			fields.append(FieldValue(nil))
		}

		self.fields = fields
	}
}

// MARK: - Field Value

public extension DSFVersion {
	/// A struct representing the component value of a version field
	struct FieldValue: CustomDebugStringConvertible {
		/// A static wildcard representation
		static let Wildcard = FieldValue(-1)

		/// The integer value of the field.
		public let value: Int32
		/// Was the value specified within the field (for example, "4.5" the major value is specified, the build is not)
		public let isSpecified: Bool
		/// Was the field value specified as a wildcard
		public let isWildcard: Bool

		init(_ value: Int32?) {
			self.value = (value ?? 0)
			self.isSpecified = (value != nil)
			self.isWildcard = (value == -1)

			assert(self.value >= -1)
		}

		public var debugDescription: String {
			guard isSpecified else { return "" }
			return (self.isWildcard ? "*" : "\(self.value)")
		}
	}
}

// MARK: - Equalities

extension DSFVersion: Equatable, Comparable {
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
	public static func compare(lhs: Self, rhs: Self) -> DSFVersion.ComparisonResult {
		// Left hand side cannot contain a wildcard range
		if lhs.hasWildcard { return .error }

		// Major check
		if lhs.major.value < rhs.major.value { return .ascending }
		if lhs.major.value > rhs.major.value { return .descending }

		// Minor check

		if lhs.minor.value < rhs.minor.value { return .ascending }
		if lhs.minor.value > rhs.minor.value { return .descending }

		// Patch check

		if lhs.patch.value < rhs.patch.value { return .ascending }
		if lhs.patch.value > rhs.patch.value { return .descending }

		// Build check

		if lhs.build.value < rhs.build.value { return .ascending }
		if lhs.build.value > rhs.build.value { return .descending }

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

		if lhs.major.isWildcard { return true } //  v* == v4
		if rhs.major.isWildcard { return true } //  v4 == v*
		if lhs.major.value != rhs.major.value { return false } //  v4 != v5

		// Minor

		if lhs.minor.isWildcard { return true } //  v4.* == v4.1
		if rhs.minor.isWildcard { return true } //  v4.3 == v4.*
		if lhs.minor.value != rhs.minor.value { return false } //  v4.5 != v4.0

		// Patch

		if lhs.patch.isWildcard { return true } //  v4.4.* == v4.4.1
		if rhs.patch.isWildcard { return true } //  v4.3.2 == v4.3.*
		if lhs.patch.value != rhs.patch.value { return false } //  v4.5.4 != v4.5.2

		// Build

		if lhs.build.isWildcard { return true } //  v4.4.5.* == v4.4.1
		if rhs.build.isWildcard { return true } //  v4.3.2 == v4.3.*
		if lhs.build.value != rhs.build.value { return false } //  v4.5.4 != v4.5.2

		return true
	}

	/// If this version object has a wildcard, returns true if 'version' is contained in its range
	///
	/// For example,
	///
	///      `4.4.*` contains `4.4.5.1000`
	///      `4.4.*` does not contain `4.5.0.1001` or `4.2.3`
	public func contains(_ version: DSFVersion) -> Bool {
		// Cannot compare if a version being compared against contains a range
		if version.hasWildcard == true { return false }

		if self.major.isWildcard { return true } //  v* == v4
		if self.major.value != version.major.value { return false } //  v4 != v5

		if self.minor.isWildcard { return true } //  v2.* == v2.4
		if self.minor.value != version.minor.value { return false } //  v2.2 != v2.4

		if self.patch.isWildcard { return true } //  v2.4.* == v2.4.5
		if self.patch.value != version.patch.value { return false } //  v2.4.3 != v2.4.6

		if self.build.isWildcard { return true } //  v2.4.5.* == v2.4.5.111
		if self.build.value != version.build.value { return false } //  v2.4.5.201 != v2.4.5.111

		// A perfect match (ie. 1.2.3.4 == 1.2.3.4).  As such it contains it!
		return true
	}

	@inlinable public static func > (lhs: Self, rhs: Self) -> Bool {
		// Left hand side cannot contain a wildcard range
		return DSFVersion.compare(lhs: lhs, rhs: rhs) == .descending
	}

	@inlinable public static func < (lhs: Self, rhs: Self) -> Bool {
		return DSFVersion.compare(lhs: lhs, rhs: rhs) == .ascending
	}

	@inlinable public static func >= (lhs: Self, rhs: Self) -> Bool {
		let result = DSFVersion.compare(lhs: lhs, rhs: rhs)
		return result == .descending || result == .same
	}

	@inlinable public static func <= (lhs: Self, rhs: Self) -> Bool {
		let result = DSFVersion.compare(lhs: lhs, rhs: rhs)
		return result == .ascending || result == .same
	}

	@inlinable public static func != (lhs: Self, rhs: Self) -> Bool {
		return DSFVersion.compare(lhs: lhs, rhs: rhs) != .same
	}
}

// MARK: - Increment support

public extension DSFVersion {
	/// Increment a field number, optionally zeroing all fields of lesser significance
	/// - Parameters:
	///   - field: The field to increment
	///   - zeroLower: if true, zeroes all lesser significant fields  (eg. 10.4.3.1000 --> 10.5.0.0)
	/// - Returns: A new DSFVersion object, or nil if the original version has a wildcard
	func increment(_ field: Field, zeroLower: Bool = true) -> DSFVersion? {
		if self.hasWildcard {
			return nil
		}
		switch field {
		case .major:
			return DSFVersion(self.major.value + 1, zeroLower ? 0 : self.minor.value, zeroLower ? 0 : self.patch.value, zeroLower ? 0 : self.build.value)
		case .minor:
			return DSFVersion(self.major.value, self.minor.value + 1, zeroLower ? 0 : self.patch.value, zeroLower ? 0 : self.build.value)
		case .patch:
			return DSFVersion(self.major.value, self.minor.value, self.patch.value + 1, zeroLower ? 0 : self.build.value)
		case .build:
			return DSFVersion(self.major.value, self.minor.value, self.patch.value, self.build.value + 1)
		}
	}
}

// MARK: - Codable support

extension DSFVersion: Codable {
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
