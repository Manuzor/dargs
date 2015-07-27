module dargs;

import pathlib;
import std.algorithm;
import std.array;
import std.range;
import std.typetuple : allSatisfy;
import std.traits : hasMember, isSomeString;
import io = std.stdio;


debug = verboseAtCompileTime;


/// Parse the run-time args.
/// Return: The remaining args that have not been parsed.
public string[] parse(T)(ref T args)
  if(isSomeArgsDescriptor!T)
{
  import core.runtime;
  return parse(args, Runtime.args);
}

/// Parse the given args.
/// Return: The remaining args that have not been parsed.
public string[] parse(T)(ref T args, string[] strargsIn)
  if(isSomeArgsDescriptor!T)
{
  import std.traits;
  import std.algorithm;
  import std.array;
  import std.range;
  import std.conv : to;
  import std.format;

  string[] errors;

  auto strargs = strargsIn.dup;

  debug io.writefln("Arg descriptions:%(\n  %)", args._argDescriptions);

  auto positionalArgDescs = args._argDescriptions.filter!(a => a.index >= 0);

  foreach(i, ref arg; strargsIn)
  {
    // Long options.
    {
      auto longArg = arg.find(args.optionPrefixLong);
      if(arg.startsWith(args.optionPrefixLong)) {
        io.writefln("Found long arg: %s", arg);
        strargs.popFront();
        continue;
      }
    }

    // Short options.
    {
      auto shortArg = arg.find(args.optionPrefixShort);
      if(arg.startsWith(args.optionPrefixShort)) {
        io.writefln("Found short arg: %s", arg);
        strargs.popFront();
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
    desc.set(args, arg);

    io.writeln("Value set.");

    strargs.popFront();
  }

  if(!errors.empty) {
    throw new Exception("Errors during parsing occurred:%(\n  %s%)");
  }

  return strargs;
}

struct ArgDesc(T)
{
  string member;
  string name;
  string[] flagNames;
  int index = -1; // <0 means it is an option, >=0 means it is a positional argument.
  string helpText;
  bool isRequired = false;

  // Setter of the argument value.
  void function(ref T, string) set = (ref _, __) { assert(0, "Invalid setter!"); };
}

private template ResolveType(T)
{
  alias ResolveType = T;
}

private template Tuple(T...)
{
  alias Tuple = T;
}

auto collectArgDescs(T)()
{
  ArgDesc!T[] all;
  int currentIndex = 0;
members:
  foreach(memberName; __traits(allMembers, T))
  {
    debug(verboseAtCompileTime) pragma(msg, "Member: " ~ memberName);
    static if(memberName[0] != '_' && __traits(compiles, typeof(__traits(getMember, T, memberName))))
    {
      alias Member = typeof(__traits(getMember, T, memberName));
      alias Attributes = Tuple!(__traits(getAttributes, __traits(getMember, T, memberName)));
      debug(verboseAtCompileTime) pragma(msg, "  Attributes: " ~ Attributes.stringof);
      auto desc = ArgDesc!T(memberName);
      foreach(attr; __traits(getAttributes, __traits(getMember, T, memberName)))
      {
        static if(__traits(compiles, typeof(attr)))
          alias Attr = typeof(attr);
        else
          alias Attr = attr;

        static if(is(Attr == T.Hidden) || is(attr == T.Hidden)) {
          debug(verboseAtCompileTime) pragma(msg, "  No setter will be set.");
          continue members;
        }
        else
        {
          static if(is(Attr == T.Name))
          {
            debug(verboseAtCompileTime) pragma(msg, `  Found "Name".`);
            static assert(__traits(compiles, desc.name = attr.name), `@Name must be used with arguments. E.g.: @Name("foo")`);
            desc.name = attr.name;
          }
          else static if(is(Attr == T.Required))
          {
            debug(verboseAtCompileTime) pragma(msg, `  Found "Required".`);
            desc.isRequired = true;
          }
          else static if(is(Attr == T.Help))
          {
            debug(verboseAtCompileTime) pragma(msg, `  Found "Required".`);
            static assert(__traits(compiles, desc.helpText = attr.content), `@Help must be used with arguments. E.g.: @Help("Some explanation.")`);
            desc.helpText = attr.content;
          }
          else static if(is(Attr == T.Option))
          {
            debug(verboseAtCompileTime) pragma(msg, `  Found "Option".`);
            static assert(__traits(compiles, desc.flagNames = attr.flagNames), `@Option must be used with arguments. E.g.: @Option("f", "file")`);
            desc.flagNames = attr.flagNames;
          }
          else
          {
            debug(verboseAtCompileTime) pragma(msg, "  Warning: Unrecognized attribute type: " ~ Attr.stringof);
          }
        }
      }

      static if(memberName == "parse")
        desc.set = (ref _, __) => assert(0, "Invalid call");

      desc.set = (ref instance, value)
      {
        // If the member accepts a string directly, do not attempt any conversions.
        static if(__traits(compiles, mixin("instance." ~ memberName ~ " = value")))
          mixin("instance." ~ memberName ~ " = value;");
        else static if(__traits(compiles, mixin("instance." ~ memberName ~ " = value.to!Member")))
          mixin("instance." ~ memberName ~ " = value.to!Member;");
        else static assert(0, "Unreachable.");
      };

      if(desc.flagNames.empty) {
        // We have a positional argument, so we set its index;
        desc.index = currentIndex++;
      }
      all ~= desc;
    }
  }
  return all;
}


template isSomeArgsDescriptor(T) {
  enum isSomeArgsDescriptor = hasMember!(T, "_argDescriptions");
}


mixin template ArgsDescriptor()
{
  alias This = typeof(this);

  static const _argDescriptions = collectArgDescs!This();

  @Hidden string optionPrefixShort = "-";
  @Hidden string optionPrefixLong = "--";

  @disable this(ArgDesc!This[]);

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
