# Version

A NumericalVersioning class supporting major, (optional) minor, (optional) patch and (optional) build fields.

<p align="center">
    <img src="https://img.shields.io/github/v/tag/dagronf/Version" />
    <img src="https://img.shields.io/badge/Swift-5.0-orange.svg" />
    <img src="https://img.shields.io/badge/License-MIT-lightgrey" />
    <a href="https://swift.org/package-manager">
        <img src="https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat" alt="Swift Package Manager" />
    </a>
</p>

## Why?

I had the need to parse version strings from JSON and XML encoded files that met the following requirements…

* Optional minor/patch/build fields
* Extract a version from a string representation eg. `"5.6.*"`
* The ability to use wildcards to support simple version checks
* Version range checking (eg. v4.0 -> v5.0)
* Swift Codable support

This class uses the [Numeric status](https://en.wikipedia.org/wiki/Software_versioning) versioning scheme (`major.minor.patch.build`).  Note that you do not need to provide all fields! This class will work quite happily with just the major/minor combo if that's all you need within your project.

## TL;DR: Simple example

```swift
let lowerBound = Version(10,4)
let upperBound = Version(10,5)

assert(lowerBound < upperBound)

// Simple checks to see version ordering
let testValue = Version(10,4,5,1001)
assert(testValue > lowerBound)
assert(upperBound > testValue)

// Read from somewhere, and try to convert to a version definition
let strVer = "10.4.5"
let myVersion = try Version(strVer)   // Throws if strVer isn't a compatible version string

assert(myVersion.major.value == 10)
assert(myVersion.minor.value == 4)
assert(myVersion.patch.value == 5)

// Simple comparison to verify if 'myVersion' is greater than our lower bound
assert(lowerBound < myVersion)

// See whether 'myVersion' was within our required version range
let range = lowerBound ..< upperBound
assert(range.contains(myVersion))  
```

## Integration

Use Swift Package Manager to add `https://github.com/dagronf/Version` to your project.

## Rules

### A field that is not provided when constructed is assumed to be 0. 
```swift
Version(10,4) ⟺ Version(10,4,0) ⟺ Version(10,4,0,0)
Version("5.6.3") ⟺ Version(5,6,3,0)
```

### A field that is assigned to `UInt.wildcard` is defined as a wildcard (*)

A wildcard will match against its position and any lesser significant positions

```swift
Version("14.7.*") ⟺ Version(14, 7, .wildcard)

Version(1, .wildcard).contains(Version(1, 1, 101))             // 1.* contains 1.1.101
Version(6, 0, 0, .wildcard).contains(Version(6, 0, 0, 101))    // 6.0.0.* contains 6.0.0.101
```
### Once a wildcard is found, any lesser significant places are ignored.

```swift
Version(1, .wildcard, 1, 101) ⟺ Version(1, .wildcard)                // 1.*.1.101 is equivalent to 1.*
```
## Creation

### Simple

```swift
let v1 = Version(1)                  // 1
let v2 = Version(2, 56)              // 2.56
let v3 = Version(15, 3, 4)           // 15.3.4
let v4 = Version(15, 3, 4, 10001)    // 15.3.4.10001

assert(v4.major.value == 15)
assert(v4.patch.value == 4)
```
### Wildcards

A wildcard value is specified as `UInt.wildcard` during construction

```swift
let w1 = Version(1, .wildcard)           // 1.*
let w2 = Version(1, 15, 9, .wildcard)    // 1.15.9.*
```

### Parsing from a string

```swift
// Version constructor throws if provided an incorrect version string
let v1   = try Version("10.2.3.*")         // OK
let v1-e = try Version("10..2.3.*")        // Throws VersionError.InvalidVersionString
let v2-e = try Version("1.2.0-rc.3")       // Throws VersionError.InvalidVersionString

// Static creator returns nil if provided an incorrect version string
let v2   = Version.TryParse("15.4.3")      // OK
let v2-e = Version.TryParse("15.a4.3")     // returns nil
```

## Equality

Simple

```swift
try Version("4.5.6") == Version(4,5,6)
try Version("12.4.0") == Version(12,4)
```

A wildcard matches any value from the wildcard position onward

```swift
Version(4,.wildcard) == Version(4,5,6)    // 4.* == 4.5.6
Version(4,5,6) == Version(4,.wildcard)    // 4.5.6 == 4.*
Version(4,5,6) == Version(4,5,.wildcard)  // 4.5.6 == 4.5.*
```

## Comparison

The version class supports the standard operators `<`, `>`, `==`, `!=`, `>=`, `<=`

```swift
// Basic comparison

let v0 = Version(10, 4)
let v1 = Version(10, 4, 4)
assert(v1 >= v0)             // v1 is a later version number

// Wildcard comparison

let v3 = Version(10, 4, .wildcard)
v3.contains(v0)              // 10.4.* contains the value 10.4

let v4 = Version(10, 5, .wildcard)
!v4.contains(v0)              // 10.5.* DOES NOT contain the value 10.4
```
## Ranges

You can use the standard Swift range operators for version checks

```swift
let range = Version(1,0) ..< Version(1,2)
XCTAssertTrue(range.contains(Version(1,1)))
```

### Closed Range Through
A range up to **_and including_** the upper bound

```swift
let range = Version(4) ... Version(5)
   
range.contains(Version(4))       // YES
range.contains(Version(4,5,3))   // YES
range.contains(Version(5))       // YES
range.contains(Version(5,1))     // NO
```

### Closed Range Up To

A range up to **_but not including_** the upper bound

```swift
let rangeUpTo = Version(4) ..< Version(5)

range.contains(Version(3,9,100))  // NO
range.contains(Version(4))        // YES
range.contains(Version(4,5,3))    // YES
range.contains(Version(5))        // NO
```

### Partial Range Support

```swift
let rangeAfter = Version(1,2) ...                   // All version numbers AFTER and including 1.2
assert(rangeAfter.contains(Version(1,2,0))
assert(rangeAfter.contains(Version(3,2))

let rangeBeforeInclusive = ... Version(7,8,1)       // All version numbers BEFORE and including 7.8.1
let rangeBeforeNonInclusive = ..< Version(7,8,1)    // All version numbers BEFORE not including 7.8.1
```

## Incrementer

Simple increment support.

```swift
let vv12 = Version(1,2)                 // Start with v1.2

let vv1201 = try vv12.increment(.build)    // Move to v1.2.0.1
assert(vv1201 == Version(1,2,0,1))

let vv121 = try vv1201.increment(.patch)   // Move from v1.2.0.1 -> v1.2.1
assert(vv121 == Version(1,2,1))

let vv13 = try vv121.increment(.minor)     // Move from v1.2.1 -> v1.3
assert(vv13 == Version(1,3))

let vv2 = try vv13.increment(.major)       // Move from v1.3 -> v2.0
assert(vv2 == Version(2))
```

## Codable support

Version is fully codable, so you can use Version objects in your codable structs/classes.

The coded value is the string version of the version (eg. `"15.3.*"`) so that it's easily and clearly interpreted within your coded text.

```swift
let v1 = Version(55, .wildcard)
let data1 = try JSONEncoder().encode(v1)
// Data contains "55.*"

let v2 = Version(1,3,4,9)
let data2 = try JSONEncoder().encode(v1)
// Data contains "1.3.4.9"
let v2rec = try JSONDecoder().decode(Version.self, from: data2)
XCTAssertEqual(v2, v2rec)
```

# Releases

### `2.0.0` 

* Now uses `Int` rather than `Int32` for field values
* Changed `TryParse()` and `init(versionString)` to throwing rather than returning `nil`.
* Parsing a string containing multiple wildcard values (eg. `10.*.*`) now throws an error.
* Trim whitespace from version string before parsing (more forgiving during JSON/XML parsing)

# License

MIT. Use it for anything you want, just attribute my work. 
Let me know if you do use it somewhere, I'd love to hear about it!

```
MIT License

Copyright (c) 2021 Darren Ford

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
