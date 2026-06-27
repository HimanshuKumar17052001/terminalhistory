#!/usr/bin/env ruby
# Second-pass cleanup for test files already partially converted.
# Removes any remaining XCTAssert* calls.

require 'fileutils'

FILES = Dir.glob('Tests/THCoreTests/*.swift')

FILES.each do |path|
  src = File.read(path)
  orig = src.dup

  # XCTAssertEqual(a, b[, msg]) -> #expect(a == b)
  src.gsub!(/XCTAssertEqual\((.*?),\s*(.*?)\)/m) do
    "#expect(#{$1} == #{$2})"
  end

  # XCTAssertNotEqual(a, b) -> #expect(a != b)
  src.gsub!(/XCTAssertNotEqual\((.*?),\s*(.*?)\)/m) do
    "#expect(#{$1} != #{$2})"
  end

  # XCTAssertTrue(x[, msg]) -> #expect(x)
  src.gsub!(/XCTAssertTrue\((.*?)\)/m) { "#expect(#{$1})" }

  # XCTAssertFalse(x) -> #expect(!x)
  src.gsub!(/XCTAssertFalse\((.*?)\)/m) { "#expect(!#{$1})" }

  # XCTAssertNil(x) -> #expect(x == nil)
  src.gsub!(/XCTAssertNil\((.*?)\)/m) { "#expect(#{$1} == nil)" }

  # XCTAssertNotNil(x) -> #expect(x != nil)
  src.gsub!(/XCTAssertNotNil\((.*?)\)/m) { "#expect(#{$1} != nil)" }

  # XCTAssertLessThan(a, b) -> #expect(a < b)
  src.gsub!(/XCTAssertLessThan\((.*?),\s*(.*?)\)/m) { "#expect(#{$1} < #{$2})" }

  # XCTAssertGreaterThan(a, b) -> #expect(a > b)
  src.gsub!(/XCTAssertGreaterThan\((.*?),\s*(.*?)\)/m) { "#expect(#{$1} > #{$2})" }

  # XCTAssertThrowsError({...}) -> #expect(throws: (any Error).self) {...}
  src.gsub!(/XCTAssertThrowsError\((\s*\{)/) { "#expect(throws: (any Error).self) #{$1}" }
  src.gsub!(/XCTAssertThrowsError\((.+?)\)/m) { "#expect(throws: (any Error).self) { try #{$1.strip} }" }

  # Clean up double try
  src.gsub!(/try try /, 'try ')

  # Any leftover XCTAssert* should be removed; flag them
  leftovers = src.scan(/XCTAssert\w+/).uniq
  if !leftovers.empty?
    puts "WARN #{path}: leftover XCTAssert calls: #{leftovers.join(', ')}"
  end

  if src != orig
    File.write(path, src)
    puts "fixed: #{path}"
  end
end
