import dunit;
import dargs;
import std.algorithm;


class Basics
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
  void simpleFlagShort()
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
  void simpleFlagLong()
  {
    static struct Args
    {
      mixin ArgsDescriptor;

      @Flag("--force")
      bool force;
    }
    auto args = Args();
    auto remaining = args.parse(["--force"]);
    assertTrue(args.force);
    assertEmpty(remaining);
  }

  @Test
  void simpleOptionShort()
  {
    static struct Args
    {
      mixin ArgsDescriptor;

      @Option("-l")
      int level;
    }
    auto args = Args();
    auto remaining = args.parse(["-l", "42"]);
    assertEquals(42, args.level);
    assertEmpty(remaining);
  }

  @Test
  void simpleOptionLong()
  {
    static struct Args
    {
      mixin ArgsDescriptor;

      @Option("--level")
      int level;
    }
    auto args = Args();
    auto remaining = args.parse(["--level", "42"]);
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
    auto remaining = args.parse(strargs);
    assertEmpty(args.foo);
    assertEquals("the answer is 42.", args.bar);
    assertEmpty(args._baz);
    assertRangeEquals(strargs[1..$], remaining);
  }

  @Test
  void stringProperty()
  {
    static struct Args
    {
      mixin ArgsDescriptor;

      @Hidden
      string theValue = "bar";

      void complex(string value) @property
      {
        this.theValue = value ~ "_" ~ this.theValue;
      }
    }
    auto args = Args();
    args.parse(["foo"], ParseOptions(true));
    assertEquals("foo_bar", args.theValue);
  }

  @Test
  void intProperty()
  {
    static struct Args
    {
      mixin ArgsDescriptor;

      @Hidden
      int value;

      // Note that names don't matter much here.
      void valueProperty(int value) @property
      {
        this.value = value;
      }

      int valueProperty() @property
      {
        return this.value;
      }
    }

    auto args = Args();
    args.parse(["42"], ParseOptions(true));
    assertEquals(42, args.value);
  }

  @Test
  void remainingArgs()
  {
    static struct Args
    {
      mixin ArgsDescriptor;

      string a;
      string b;
      string c;
    }

    auto strargs = "A B C D E F G H".splitter();
    auto args = Args();
    auto remaining = args.parse(strargs);
    assertEquals("A", args.a);
    assertEquals("B", args.b);
    assertEquals("C", args.c);
    assertEquals("D E F G H".splitter(), remaining);

    remaining = args.parse(remaining);
    assertEquals("D", args.a);
    assertEquals("E", args.b);
    assertEquals("F", args.c);
    assertEquals("G H".splitter(), remaining);
    assertEquals("G H".splitter(), args.parse(args.parse(strargs)));
  }
}


mixin Main;
