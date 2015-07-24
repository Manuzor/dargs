module dargs;

import pathlib;
import std.algorithm;
import std.array;
import std.range;
import std.typetuple : allSatisfy;
import io = std.stdio;


struct ArgDesc
{
  string member;
  string name;
  string[] flagNames;
  string helpText;
  bool isRequired = false;
}

private template ResolveType(T)
{
  alias ResolveType = T;
}

private template Tuple(T...)
{
  alias Tuple = T;
}

private ArgDesc[] collectArgDescs(T)()
{
  ArgDesc[] all;
members:
  foreach(memberName; __traits(allMembers, T))
  {
    debug pragma(msg, "Member: " ~ memberName);
    static if(__traits(compiles, typeof(__traits(getMember, T, memberName))))
    {
      alias Member = typeof(__traits(getMember, T, memberName));
      alias Attributes = Tuple!(__traits(getAttributes, __traits(getMember, T, memberName)));
      debug pragma(msg, "Attributes: " ~ Attributes.stringof);
      auto desc = ArgDesc(memberName);
      foreach(attr; __traits(getAttributes, __traits(getMember, T, memberName)))
      {
        static if(__traits(compiles, typeof(attr)))
          alias Attr = typeof(attr);
        else
          alias Attr = attr;

        static if(is(Attr == T.Hidden) || is(attr == T.Hidden)) {
          continue members;
        }
        else static if(is(Attr == T.Name))
        {
          static assert(__traits(compiles, desc.name = attr.name), `@Name must be used with arguments. E.g.: @Name("foo")`);
          desc.name = attr.name;
        }
        else static if(is(Attr == T.Required))
        {
          desc.isRequired = true;
        }
        else static if(is(Attr == T.Help))
        {
          static assert(__traits(compiles, desc.helpText = attr.content), `@Help must be used with arguments. E.g.: @Help("Some explanation.")`);
          desc.helpText = attr.content;
        }
        else static if(is(Attr == T.Option))
        {
          static assert(__traits(compiles, desc.flagNames = attr.flagNames), `@Option must be used with arguments. E.g.: @Option("f", "file")`);
          desc.flagNames = attr.flagNames;
        }
        else
        {
          debug pragma(msg, "Warning: Unrecognized attribute type: " ~ Attr.stringof);
        }
      }
      all ~= desc;
    }
  }
  return all;
}

private struct _Hidden {}

mixin template CommandLineArguments()
{
  alias Hidden = _Hidden;

  alias This = typeof(this);

  @Hidden
  ArgDesc[] _argDescriptions = collectArgDescs!This();

  /// Parse the run-time args.
  /// Return: The remaining args that have not been parsed.
  @Hidden
  string[] parse()
  {
    import core.runtime;
    return parse(Runtime.args);
  }

  /// Parse the given args.
  /// Return: The remaining args that have not been parsed.
  @Hidden
  string[] parse(string[] argsIn)
  {
    import std.traits;

    auto args = argsIn.dup;

    io.writefln("Arg descriptions:%-(\n  %s%)", _argDescriptions);

    return args;
  }

  @Hidden
  struct Required { @disable this(); }

  @Hidden
  struct Option
  {
    string[] flagNames;

    @disable this();

    this(FlagNames...)(FlagNames flagNames)
      if(allSatisfy!(isSomeString, FlagNames))
    {
      foreach(ref flagName; flagNames)
      {
        this.flagNames ~= flagName;
      }
    }
  }

  @Hidden
  struct Help
  {
    string content;

    @disable this();

    this(string content) { this.content = content; }
  }

  @Hidden
  struct Name
  {
    string name;

    @disable this();
    this(string name) { this.name = name; }
  }
}

struct Args
{
  mixin CommandLineArguments;

  @Name("file_path")
  @Required
  @Help("The path to the file.")
  Path filePath;

  @Option("l", "last_loaded")
  @Name("last_loaded")
  @Help("Whether to load the last used model on startup.")
  bool startWithLastLoaded = false;

  @Option("s")
  @Help("Load this scene instead of the default one.")
  Path scene;

  @Hidden
  bool magic;

  @Name("bobbels")
  bool lawlypopz() { return false; }
}

void main()
{
  io.writeln("+++ Begin +++");
  scope(exit) io.writeln("--- End ---");
  auto args = Args();
  args.parse();
}
