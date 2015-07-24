module dargs;

import pathlib;
import std.algorithm;
import std.array;
import std.range;
import std.typetuple : allSatisfy;
import std.traits : hasMember;
import io = std.stdio;


struct ArgDesc
{
  string member;
  string name;
  string[] flagNames;
  int index = -1; // <0 means it is an option, >=0 means it is a positional argument.
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

ArgDesc[] collectArgDescs(T)()
{
  ArgDesc[] all;
  int currentIndex = 0;
members:
  foreach(memberName; __traits(allMembers, T))
  {
    debug pragma(msg, "Member: " ~ memberName);
    static if(memberName[0] != '_' && __traits(compiles, typeof(__traits(getMember, T, memberName))))
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
      if(desc.flagNames.empty) {
        // We have a positional argument, so we set its index;
        desc.index = currentIndex++;
      }
      all ~= desc;
    }
  }
  return all;
}


mixin template CommandLineArguments()
{
  alias This = typeof(this);

  static const(ArgDesc[]) _argDescriptions = collectArgDescs!This();

  @Hidden string optionPrefixShort = "-";
  @Hidden string optionPrefixLong = "--";

  @disable this(ArgDesc[]);

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
    import std.algorithm;
    import std.array;
    import std.range;
    import std.conv : to;
    import std.format;

    string[] errors;

    auto args = argsIn.dup;

    debug io.writefln("Arg descriptions:%(\n  %)", _argDescriptions);

    auto positionalArgDescs = _argDescriptions.filter!(a => a.index >= 0);

    foreach(ref arg; argsIn)
    {
      // Long options.
      {
        auto longArg = arg.find(optionPrefixLong);
        if(arg.startsWith(optionPrefixLong)) {
          io.writefln("Found long arg: %s", arg);
          args.popFront();
          continue;
        }
      }

      // Short options.
      {
        auto shortArg = arg.find(optionPrefixLong);
        if(arg.startsWith(optionPrefixLong)) {
          io.writefln("Found short arg: %s", arg);
          args.popFront();
          continue;
        }
      }

      // Positional argument.
      if(positionalArgDescs.empty) {
        errors ~= `Did not expect positional argument: %s`.format(arg);
        continue;
      }


      auto desc = positionalArgDescs.front();
      scope(success) positionalArgDescs.popFront();

      io.writefln("Found positional arg: %s (%s)", arg, desc.member);

      // Positional Arguments.
      alias Member = typeof(__traits(getMember, This, "theFoo"));
      __traits(getMember, This, "theFoo") = arg.to!Member();


      args.popFront();
    }

    if(!errors.empty) {
      throw new Exception("Errors during parsing occurred:%(\n  %s%)");
    }

    return args;
  }

  struct Required { @disable this(); }

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

  struct Help
  {
    string content;

    @disable this();

    this(string content) { this.content = content; }
  }

  struct Name
  {
    string name;

    @disable this();
    this(string name) { this.name = name; }
  }

  struct Hidden { @disable this(); }
}
