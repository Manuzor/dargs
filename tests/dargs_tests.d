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
    assertEquals("hello world", args.theFoo);
    assertEmpty(remaining);
  }

  @Test
  void simpleFlag()
  {
    static struct Args
    {
      mixin ArgsDescriptor;

      @Flag("-f")
      bool force;
    }
    auto args = Args();
    auto remaining = args.parse(["-f"]);
    assertTrue(args.force);
    assertEmpty(remaining);
  }

  @Test
  void simpleOption()
  {
    static struct Args
    {
      mixin ArgsDescriptor;

      @Option("-l")
      int level;
    }
    auto args = Args();
    auto remaining = args.parse(["-l 42"]);
    assertEquals(42, args.level);
    assertEmpty(remaining);
  }

  @Test
  void hideAndSeek()
  {
    static struct Args
    {
      mixin ArgsDescriptor;

      @Hidden
      string foo;

      string bar;

      string _baz; // As good as @Hidden.
    }
    auto args = Args();
    auto strargs = ["the answer is 42.", "You better believe it!"];
    auto remaining = args.parse(strargs, ParseOptions(true));
    assertEmpty(args.foo);
    assertEquals("the answer is 42.", args.bar);
    assertEmpty(args._baz);
    assertRangeEquals(strargs[1..$], remaining);
  }

  @Test
  @Ignore("Not implemented.")
  void property()
  {
    static struct Args
    {
      mixin ArgsDescriptor;

      @Hidden
      string theValue = "bar";

      @property void complex(string value)
      {
        theValue = value ~ "_" ~ theValue;
      }
    }
    auto args = Args();
    args.parse(["foo"]);
    assertEquals("foo_bar", args.theValue);
  }
}


mixin Main;
