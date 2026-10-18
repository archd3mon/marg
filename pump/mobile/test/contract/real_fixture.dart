import 'dart:convert';
import 'dart:io';

/// Loads a REAL backend response captured by `pump/backend/scripts/capture_fixtures.py`.
/// Tests run with cwd = pump/mobile, so the path is relative to it.
dynamic realFixture(String name) =>
    jsonDecode(File('test/fixtures/real/$name').readAsStringSync());
