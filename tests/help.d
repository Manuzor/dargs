import dargs;
import dunit;

class Help
{
  mixin UnitTest;

  static struct Args1
  {
    mixin ArgsDescriptor;

    // Options
    // =======

    @Name("force")
    @Flag("-f", "--force")
    @Help("Whether to force something or not.")
    string theForceValue;

    @Name("verbose")
    @Flag("-v", "--verbose")
    @Help("Whether to be verbose or not.")
    bool verbose;

    @Name("version")
    @Flag("--version")
    @Help("Show the version and exit.")
    bool showVersion;

    // Positional Arguments
    // ====================
    
    @Name("INPUT")
    @Help("The input path.")
    @Required
    string input;

    @Name("OUTPUT")
    @Help("The output path.")
    @Required
    string output;
  }

  @Test
  void usage()
  {
    import std.format;
    import io = std.stdio;
    import std.array;

    auto args = Args1();
    io.writefln("Args1._argDescriptions: %s", (cast()Args1._argDescriptions).array());

    auto expected = q"{%s [-f][-v][--version] INPUT OUTPUT}".format(executableName);
    assertEquals(expected, args.usage());
  }
}
