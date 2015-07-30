module dargs;

import pathlib;
import std.algorithm;
import std.array;
import std.range;
import std.typetuple : allSatisfy;
import std.traits;
import std.typecons : Typedef;
import io = std.stdio;
import std.conv : to;
import std.format;


//debug = verboseAtCompileTime;
//debug = verboseAtRunTime;

struct ParseOptions
{
  bool strict;
  bool greedy;
  bool stopAfterPositionals;

  string toString() const
  {
    return `ParseOptions(strict = %s)`.format(this.strict);
  }
}


/// Parse the run-time args.
/// Return: The remaining args that have not been parsed.
public auto parse(T)(ref T args, ParseOptions parseOptions = ParseOptions())
  if(isSomeArgsDescriptor!T)
{
  import core.runtime;
  return parse(args, Runtime.args[1..$], parseOptions);
}

/// Parse the given args.
/// Return: The remaining args that have not been parsed.
public auto parse(T, R)(ref T argsContainer, R args, ParseOptions parseOptions = ParseOptions())
  if(isSomeArgsDescriptor!T && isInputRange!R)
{
  string[] errors;
  const originalArgs = args;

  scope(exit)
  {
    if(!errors.empty)
    {
      auto msg = "Errors during parsing occurred:%-(\n  %s%)\nArguments were: %s".format(errors, array(cast()originalArgs));
      debug msg = "%s\n%s".format(msg, parseOptions.to!string());
      throw new Exception(msg);
    }
  }

  debug(verboseAtRunTime) io.writefln("Arg descriptions:%(\n  %s%)", argsContainer._argDescriptions);

  auto positionalArgDescs = argsContainer._argDescriptions.filter!(a => a.index >= 0);
  auto optionDescs = argsContainer._argDescriptions.filter!(a => a.index < 0);

  int i = 0;
  while (true)
  {
    scope(exit) ++i;

    // If we don't have anything to parse anymore, we stop parsing.
    if(args.empty) {
      break;
    }

    // If there are no more possible arguments to set, we are done as well.
    if(positionalArgDescs.empty && optionDescs.empty) {
      break;
    }

    if(positionalArgDescs.empty && parseOptions.stopAfterPositionals) {
      break;
    }

    const parseError = (string msg) {
      errors ~= "Argument %s: %s".format(i + 1, msg);
    };

    auto arg = args.front;
    auto prevArgs = args;
    args.popFront();

    debug(verboseAtRunTime) io.writefln("Arg: %s", arg);

    enum OptionType { Positional, Long, Short }
    auto type = OptionType.Positional;

    if(arg.startsWith("--")) {
      type = OptionType.Long;
    }
    else if(arg.startsWith("-")) {
      type = OptionType.Short;
    }

    debug(verboseAtRunTime) io.writefln("Option Type: %s", type);

    if(type != OptionType.Positional && optionDescs.empty)
    {
      parseError(`Unexpected option "%s". Duplicate?`.format(arg));
      continue;
    }

    if(type != OptionType.Positional)
    {
      // Split by '='. E.g.: "foo=bar=baz" => ["foo", "=", "bar=baz"];
      auto theSplit = arg.findSplit("=");
      auto name = theSplit[0];
      auto value = theSplit[2];
      auto optionPos = optionDescs.find!(a => !a.optNames.find(name).empty);
      if(optionPos.empty) {
        parseError(`Unknown option "%s". Candidates: %s`.format(name, optionDescs.map!(a => a.optNames[0]).array));
        continue;
      }
      auto optionDesc = optionPos.front; // the result of "find".
      if(optionDesc.isFlag)
      {
        if(!value.empty) {
          parseError(`Unexpected value for flag "%s": %s`.format(name, value));
          continue;
        }
        if(!theSplit[1].empty) {
          parseError(`Unexpected delimiter for flag "%s".`.format(name));
          continue;
        }

        value = "true";
      }
      // The value might be in the next argument, e.g. `--hello world` instead of `--hello=world`
      else if(value.empty)
      {
        // Invalid if no more arguments are left at this point.
        if(args.empty)
          goto missingArgument;
        
        // Make sure the current `arg` is up to date.
        arg = args.front;
        args.popFront();

        if(arg.startsWith(argsContainer.optionPrefixLong) || arg.startsWith(argsContainer.optionPrefixShort))
          goto missingArgument;

        // `arg` is the new `value`.
        value = arg;
        goto argumentFound;

      missingArgument:
          parseError(`Missing argument for option "%s".`.format(name));
          continue;
      argumentFound:
      }

      optionDesc.set(argsContainer, value);
    }
    else
    {
      if(positionalArgDescs.empty)
      {
        // At this point, we have no unprocessed positional arguments left,
        // which means there was more supplied than expected.
        if(parseOptions.strict) {
          parseError(`Did not expect positional argument: "%s"`.format(arg));
        }
        if(parseOptions.greedy) {
          continue;
        }
        // Restore previous args since we don't want to consume the current arg.
        args = prevArgs;
        break;
      }

      auto memberDesc = positionalArgDescs.front;
      positionalArgDescs.popFront();

      memberDesc.set(argsContainer, arg);
    }
  }

  return args;
}

struct ArgDesc(T)
{
  string member;
  string name;
  string[] optNames;
  int index = -1; // <0 means it is an option, >=0 means it is a positional argument.
  string helpText;
  bool isRequired = false;
  int numArgs = 1; // Only relevant if any optNames are set.

  @property bool isFlag() const { return this.numArgs == 0; }

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

/// Motivation: If T is a type already, typeof(T) does not compile.
private template SafeTypeOf(alias T)
{
  static if(__traits(compiles, typeof(T)))
    alias SafeTypeOf = typeof(T);
  else
    alias SafeTypeOf = T;
}

bool hasUdaWithName(T, alias memberName, alias udaName)()
{
  foreach(attr; __traits(getAttributes, __traits(getMember, T, memberName)))
  {
    // Check whether some UDA named @Hidden is present.
    static if(SafeTypeOf!(attr).stringof == udaName)
    {
      return true;
    }
  }
  return false;
}

bool isIgnored(T, alias memberName)()
{
  static if(memberName[0] == '_') {
    // Ignore variables starting with an underscore, e.g. __ctor.
    debug(verboseAtCompileTime) pragma(msg, "Starts with underscore.");
    return true;
  }
  else static if(hasUdaWithName!(T, memberName, "Hidden")) {
    debug(verboseAtCompileTime) pragma(msg, `Has UDA named "Hidden".`);
    return true;
  }
  else static if(hasMember!(ReferenceDescriptor, memberName)) {
    // Ignore all members that are in the reference descriptor.
    debug(verboseAtCompileTime) pragma(msg, "Is the reference descriptor.");
    return true;
  }
  else static if(isCallable!(__traits(getMember, T, memberName)) && (functionAttributes!(__traits(getMember, T, memberName)) & FunctionAttribute.property) != 0) {
    debug(verboseAtCompileTime) pragma(msg, "Found property");
    return false;
  }
  else static if(!__traits(compiles, typeof(__traits(getMember, T, memberName)))) {
    // Ignore members where we cannot take the type of. We are only interested in member variables.
    debug(verboseAtCompileTime) pragma(msg, "Unable to take the type of the member.");
    return true;
  }
  else
  {
    debug(verboseAtCompileTime) pragma(msg, `Is not ignored.`);
    return false;
  }
}

auto collectArgDescs(T)()
{
  ArgDesc!T[] all;
  int currentIndex = 0;
members:
  debug(verboseAtCompileTime) pragma(msg, "In " ~ fullyQualifiedName!T);
  foreach(memberName; __traits(allMembers, T))
  {
    debug(verboseAtCompileTime) pragma(msg, "  Member: " ~ memberName);
    static if(!isIgnored!(T, memberName))
    {
      static if(__traits(compiles, typeof(__traits(getMember, T, memberName))))
        alias Member = typeof(__traits(getMember, T, memberName));

      debug(verboseAtCompileTime)
      {
        alias Attributes = Tuple!(__traits(getAttributes, __traits(getMember, T, memberName)));
        pragma(msg, "    Attributes: " ~ Attributes.stringof);
      }
      auto desc = ArgDesc!T(memberName);
      foreach(attr; __traits(getAttributes, __traits(getMember, T, memberName)))
      {
        alias Attr = SafeTypeOf!attr;

        static if(is(Attr == T.Name))
        {
          debug(verboseAtCompileTime) pragma(msg, `    Found "Name".`);
          static assert(__traits(compiles, desc.name = attr.name), `@Name must be used with arguments. E.g.: @Name("foo")`);
          desc.name = attr.name;
        }
        else static if(is(Attr == T.Required))
        {
          debug(verboseAtCompileTime) pragma(msg, `    Found "Required".`);
          desc.isRequired = true;
        }
        else static if(is(Attr == T.Help))
        {
          debug(verboseAtCompileTime) pragma(msg, `    Found "Help".`);
          static assert(__traits(compiles, desc.helpText = attr.content), `@Help must be used with arguments. E.g.: @Help("Some explanation.")`);
          desc.helpText = attr.content;
        }
        else static if(is(Attr == T.Option))
        {
          debug(verboseAtCompileTime) pragma(msg, `    Found "Option".`);
          static assert(__traits(compiles, desc.optNames = attr.optNames), `@Option must be used with arguments. E.g.: @Option("f", "file")`);
          desc.optNames = attr.optNames;
          desc.numArgs = attr.numArgs;
        }
        else static if(is(Attr == T.Flag))
        {
          debug(verboseAtCompileTime) pragma(msg, `    Found "Flag".`);
          static assert(__traits(compiles, desc.optNames = attr.optNames), `@Flag must be used with arguments. E.g.: @Flag("f", "file")`);
          desc.optNames = attr.optNames;
          desc.numArgs = attr.numArgs;
        }
        else static if(is(Attr == T.NumArgs))
        {
          debug(verboseAtCompileTime) pragma(msg, `    Found "NumArgs".`);
          static assert(__traits(compiles, desc.numArgs = attr.value), `@NumArgs must be used with arguments. E.g.: @NumArgs(1)`);
          desc.numArgs = attr.value;
        }
        else
        {
          debug(verboseAtCompileTime) pragma(msg, "    Warning: Unrecognized attribute type: " ~ Attr.stringof);
        }
      }

      desc.set = (ref instance, strValue)
      {
        // If the member accepts a string directly, do not attempt any conversions.
        static if(__traits(compiles, mixin("instance." ~ memberName ~ " = strValue")))
          mixin("instance." ~ memberName ~ " = strValue;");
        else static if(__traits(compiles, mixin("instance." ~ memberName ~ " = strValue.to!Member()")))
          mixin("instance." ~ memberName ~ " = strValue.to!Member();");
        else static assert(0, "Unreachable. Do you have a @property function without a getter?");
      };

      if(desc.optNames.empty) {
        // We have a positional argument, so we set its index;
        desc.index = currentIndex++;
      }

      if(desc.name.empty) {
        desc.name = memberName;
      }

      all ~= desc;
    }
  }

  static if(!is(T == ReferenceDescriptor))
    assert(!all.empty, "No argument descriptions found in " ~ fullyQualifiedName!T);
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

  struct NumArgs
  {
    int value;
  }

  struct _OptionImpl(int defaultNumArgs)
  {
    import std.traits : isSomeString;

    string[] optNames;
    int numArgs = defaultNumArgs;

    @disable this();

    this(FlagNames...)(FlagNames optNames)
      if(allSatisfy!(isSomeString, FlagNames))
    {
      foreach(ref arg; optNames)
      {
        this.optNames ~= arg;
      }
    }
  }

  alias Flag = _OptionImpl!0;
  alias Option = _OptionImpl!1;

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

private struct ReferenceDescriptor
{
  mixin ArgsDescriptor;
}
