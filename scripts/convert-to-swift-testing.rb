#!/usr/bin/env ruby
# Converts XCTest test files to Swift Testing.
# Run from repo root. Idempotent.

require 'fileutils'

FILES = %w[
  Tests/THCoreTests/CLISkeletonTests.swift
  Tests/THCoreTests/ConfigTests.swift
  Tests/THCoreTests/ExportTests.swift
  Tests/THCoreTests/GzipCodecTests.swift
  Tests/THCoreTests/PTYCapturerTests.swift
  Tests/THCoreTests/RetentionTests.swift
  Tests/THCoreTests/SearchTests.swift
  Tests/THCoreTests/SessionRecorderTests.swift
  Tests/THCoreTests/SessionReplayerTests.swift
  Tests/THCoreTests/SessionStoreTests.swift
  Tests/THCoreTests/TerminalLauncherTests.swift
  Tests/THCoreTests/ULIDTests.swift
]

FILES.each do |path|
  src = File.read(path)

  # Already converted?
  if src.include?('import Testing')
    puts "skip: #{path} (already Swift Testing)"
    next
  end

  out = src.dup

  # 1. Imports
  out.gsub!(/^import XCTest$/, 'import Testing')

  # 2. Class declaration: "final class FooTests: XCTestCase" -> "@Suite struct FooTests"
  out.gsub!(/^(\s*)final class (\w+Tests): XCTestCase \{/, '\1@Suite struct \2 {')

  # 3. testFoo() -> @Test func foo()
  # Method signature inside a class/struct: optional `func test...` -> `@Test func ...`
  # Only at top-level inside the suite (4-space indent in our test files).
  out.gsub!(/^(\s+)func (test\w+)\(/, '\1@Test func \2(')

  # 4. Assertions (regex lookaheads dropped — they were too restrictive)
  # XCTAssertEqual(a, b) -> #expect(a == b)
  out.gsub!(/XCTAssertEqual\((.*?),\s*(.*?)\)/m) do |m|
    a, b = $1, $2
    "#expect(#{a} == #{b})"
  end

  # XCTAssertNotEqual(a, b) -> #expect(a != b)
  out.gsub!(/XCTAssertNotEqual\((.*?),\s*(.*?)\)/m) do |m|
    "#expect(#{$1} != #{$2})"
  end

  # XCTAssertTrue(...) -> #expect(...)
  out.gsub!(/XCTAssertTrue\(/, '#expect(')

  # XCTAssertFalse(...) -> #expect(!...)
  out.gsub!(/XCTAssertFalse\((.*?)\)/m) do |m|
    "#expect(!#{$1})"
  end

  # XCTAssertNil(x) -> #expect(x == nil)
  out.gsub!(/XCTAssertNil\((.*?)\)/m) do |m|
    "#expect(#{$1} == nil)"
  end

  # XCTAssertNotNil(x) -> #expect(x != nil)
  out.gsub!(/XCTAssertNotNil\((.*?)\)/m) do |m|
    "#expect(#{$1} != nil)"
  end

  # XCTAssertLessThan(a, b) -> #expect(a < b)
  out.gsub!(/XCTAssertLessThan\((.*?),\s*(.*?)\)/m) do |m|
    "#expect(#{$1} < #{$2})"
  end

  # XCTAssertGreaterThan(a, b) -> #expect(a > b)
  out.gsub!(/XCTAssertGreaterThan\((.*?),\s*(.*?)\)/m) do |m|
    "#expect(#{$1} > #{$2})"
  end

  # XCTAssertThrowsError { expr } -> #expect(throws: (any Error).self) { expr }
  # XCTAssertThrowsError(expr) -> #expect(throws: (any Error).self) { try expr }
  out.gsub!(/XCTAssertThrowsError\((\s*\{)/) { "#expect(throws: (any Error).self) #{$1}" }
  out.gsub!(/XCTAssertThrowsError\((.+?)\)/m) do |m|
    "#expect(throws: (any Error).self) { try #{$1.strip} }"
  end

  # try! expr -> try expr (Swift Testing handles rethrowing)
  out.gsub!(/try!/, 'try')

  File.write(path, out)
  puts "converted: #{path}"
end
