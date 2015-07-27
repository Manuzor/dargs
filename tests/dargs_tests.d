module dargs_tests;

import io = std.stdio;
import dunit;
import dargs;


class Tests
{
  mixin UnitTest;

  @Test
  void simplePositional()
  {
    static struct Args
    {
      mixin ArgsDescriptor;

      string theFoo;
    }
    auto args = Args();
    auto remaining = args.parse([ "hello world" ]);
    assertEquals(args.theFoo, "hello world");
    assertEmpty(remaining);
  }
}


mixin Main;
