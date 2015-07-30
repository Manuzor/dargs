import dargs;
import dunit;

import std.algorithm;

class Subcommands
{
  mixin UnitTest;

  static struct Foo
  {
    mixin ArgsDescriptor;

    @Option("-o", "--output")
    string output;

    string input;
  }

  static struct Bar
  {
    mixin ArgsDescriptor;

    @Flag("-f", "--force")
    bool force;
  }

  static struct Args
  {
    mixin ArgsDescriptor;

    @Flag("-v", "--verbose")
    bool verbose;

    string cmd;
  }

  @Test
  void testFoo()
  {
    auto args = Args();
    auto cmdArgs = args.parse(splitter("-v foo hello -o /dev/null"));
    assertEquals("foo", args.cmd);
    auto foo = Foo();
    assertEmpty(foo.parse(cmdArgs));
    assertEquals("hello", foo.input);
    assertEquals("/dev/null", foo.output);
  }

  @Test
  void testBar()
  {
    auto args = Args();
    auto opts = ParseOptions();
    opts.stopAfterPositionals = true;
    auto cmdArgs = args.parse(splitter("bar --force"), opts);
    assertEquals("bar", args.cmd);
    auto bar = Bar();
    assertEmpty(bar.parse(cmdArgs));
    assertTrue(bar.force);
  }
}
