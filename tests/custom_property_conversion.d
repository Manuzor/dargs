import dargs;
import dunit;

class CustomPropertyConversion
{
  mixin UnitTest;

  static struct Data
  {
    int a;
    int b;
    float c;
  }

  static struct Args
  {
    mixin ArgsDescriptor;

    @Hidden
    Data data;

    @Option("--data")
    void dataConverter(string value) @property
    {
      import std.array : split;
      import std.conv : to;

      auto theSplit = value.split(';');
      assert(theSplit.length == 3);
      this.data.a = theSplit[0].to!int();
      this.data.b = theSplit[1].to!int();
      this.data.c = theSplit[2].to!float();
    }
  }

  @Test
  void stringProperty()
  {
    auto args = Args();
    args.parse(["--data", "1;2;3.14"]);
    assertEquals(Data(1, 2, 3.14f), args.data);
  }
}
