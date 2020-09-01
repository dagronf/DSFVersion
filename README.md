# DSFVersion

A simple version class supporting major, (optional) minor, (optional) patch and (optional) build integer values.

![](https://img.shields.io/badge/Swift-5.0+-orange.svg) ![](https://img.shields.io/badge/License-MIT-lightgrey) [![](https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager)

## Rules

### A field that is not provided when constructed is assumed to be 0. 
```swift
DSFVersion(10,4) ⟺ DSFVersion(10,4,0) ⟺ DSFVersion(10,4,0,0)
DSFVersion("5.6.3") ⟺ DSFVersion(5,6,3,0)
```

### A field that is -1 is defined as a wildcard (*)

A wildcard will match against its position and any lesser significant positions

```swift
DSFVersion("14.7.*") ⟺ DSFVersion(14,7,-1)                 // "14.7.*" is the same as 14.7.-1

Version(1, -1) contains Version(1, 1, 101)             // 1.* contains 1.1.101
Version(6, 0, 0, -1) contains Version(6, 0, 0, 101)    // 6.0.0.* contains 6.0.0.101
```
### Once a wildcard is found, any lesser significant places are ignored.

```swift
Version(1, -1, 1, 101) ⟺ Version(1, -1)              // 1.*.1.101 is equivalent to 1.*
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

```swift
let w1 = Version(1, -1)           // 1.*
let w2 = Version(1, 15, 9, -1)    // 1.15.9.*
```

### Parsing from a string

```swift
// Version constructor throws if provided an incorrect version string
let v1   = try Version("10.2.3.*")         // OK
let v1-e = try Version("10..2.3.*")	       // Throws VersionError.InvalidVersionString

// Static creator returns nil if provided an incorrect version string
let v2   = Version.TryParse("15.4.3")      // OK
let v2-e = Version.TryParse("15.a4.3")     // returns nil
```

## Equality

Simple

```swift
try Version("4.5.6") == Version(4,5,6)
```

A wildcard matches any value from the wildcard position onward

```swift
Version(4,-1) == Version(4,5,6)    // 4.* == 4.5.6
Version(4,5,6) == Version(4,-1)    // 4.5.6 == 4.*
Version(4,5,6) == Version(4,5,-1)  // 4.5.6 == 4.5.*
```

## Comparison

```swift
// Basic comparison

let v0 = Version(10, 4)
let v1 = Version(10, 4, 4)
assert(v1 >= v0)             // v1 is a later version number

// Wildcard comparison

let v3 = Version(10, 4, *)
v3.contains(v0)              // 10.4.* contains the value 10.4

let v4 = Version(10, 5, *)
!v4.contains(v0)              // 10.5.* DOES NOT contain the value 10.4
```
## Wildcards

### Ranges

#### Version.ClosedRangeThrough 
A range up to **_and including_** the upper bound

```swift
let range = Version.ClosedRangeThrough(
   lowerBound: Version(4),
   upperBound: Version(5))
   
range.contains(Version(4))       // YES
range.contains(Version(4.5.3))   // YES
range.contains(Version(5))       // YES
```

#### Version.ClosedRangeUpTo 

A range up to **_but not including_** the upper bound

```swift
let range = ClosedRangeUpTo(
   lowerBound: Version(4),
   upperBound: Version(5))

range.contains(Version(4))       // YES
range.contains(Version(4.5.3))	// YES
range.contains(Version(5))       // NO
```


## Codable support

```swift
let v1 = Version(55, -1)
let data1 = try JSONEncoder().encode(v1)
// Data contains "55.*"

let v2 = Version(1,3,4,9)
let data2 = try JSONEncoder().encode(v1)
// Data contains "1.3.4.9"
let v2rec = try JSONDecoder().decode(Version.self, from: data2)
XCTAssertEqual(v2, v2rec)
```

# License

```
MIT License

Copyright (c) 2020 Darren Ford

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
