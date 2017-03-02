/**
	Encodes and decodes punycode strings, per
	$(LINK2 https://www.ietf.org/rfc/rfc3492.txt, RFC3492).
	Punycode is primarily used for converting URIs or IRIs containing non-ASCII
	characters into URIs or IRIs that are entirely ASCII, and vice versa.
	This punycode codec is based upon the original implementation found in
	$(LINK2 https://www.ietf.org/rfc/rfc3492.txt, RFC3492).

	License:	$(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: 	Shotaro Yamada (Sinkuu)
	Source: 	$(PHOBOSSRC std/net/_punycode.d)
	Standards: 	$(LINK2 https://www.ietf.org/rfc/rfc3492.txt, RFC3492)
*/
module punycode;

import std.ascii : isASCII, isUpper, isLower, isDigit;
import std.conv : to;
import std.exception : enforce;
import std.traits : isSomeString;
import std.array : insertInPlace;
import std.algorithm.searching : all;
import core.checkedint;

version (unittest)
{
	import std.exception : assertThrown, collectExceptionMsg;
}

private immutable uint base = 36;
private immutable ubyte initialN = 0x80;
private immutable uint initialBias = 72;
private immutable uint tmin = 1;
private immutable uint tmax = 26;
private immutable uint damp = 700;
private immutable uint skew = 38;

/**
	Converts an UTF string to a Punycode string.
	Params: str = A UTF-encoded string that should be encoded into Punycode
	Returns: A punycode-encoded string
	Throws: PunycodeException if an internal error occured
*/
S punyEncode(S)(in S str) @safe pure
if (isSomeString!S)
{
	import std.functional : not;
	import std.algorithm.iteration : filter;
	import std.array : array, appender, Appender;
	import std.algorithm.sorting : sort;
	
	bool arithmeticOverflow;

	static char encodeDigit(uint x)
	{
		if (x <= 25) return cast(char)('a' + x);
		else if (x <= 35) return cast(char)('0' + x - 26);
		assert(0, "Invalid digit to encode");
	}
	
	enforce!PunycodeException(str.length <= uint.max);
	dstring dstr = str.to!dstring;
	auto ret = appender!S;
	ret ~= dstr.filter!isASCII;
	uint handledLength = cast(uint) ret.data.length;
	immutable uint basicLength = handledLength;
	if (handledLength > 0) ret ~= '-';
	if (handledLength == dstr.length) return ret.data;
	
	auto ascendingNonAsciiUints = (() @trusted => (cast(uint[]) (dstr.filter!(not!isASCII).array)).sort!"a < b")();
	dchar n = initialN;
	uint delta = 0;
	uint bias = initialBias;
	while (handledLength < dstr.length)
	{
		dchar m = void;
		while ((m = ascendingNonAsciiUints.front) < n) ascendingNonAsciiUints.popFront();
		delta = addu (delta, (m - n) * (handledLength + 1), arithmeticOverflow);
		enforce!PunycodeException(!arithmeticOverflow, "Arithmetic overflow");
		n = m;
		foreach (c; dstr)
		{
			if (c < n)
			{
				delta = addu(delta, 1, arithmeticOverflow);
				enforce!PunycodeException(!arithmeticOverflow, "Arithmetic overflow");
			}
			else if (c == n)
			{
				uint q = delta;
				for (uint k = base;;k += base)
				{
					immutable t = k <= bias ? tmin :
						k >= bias + tmax ? tmax : k - bias;
					if (q < t) break;
					ret ~= encodeDigit(t + (q - t) % (base - t));
					q = (q - t) / (base - t);
				}
				ret ~= encodeDigit(q);
				bias = adaptBias(delta, cast(uint)handledLength + 1, handledLength == basicLength);
				delta = 0;
				handledLength++;
			}
		}
		delta++;
		n++;
	}
	return ret.data;
}

///
@safe pure
unittest
{
	assert(punyEncode("mañana") == "maana-pta");
}

/**
	Converts a Punycode string to an UTF-encoded string.
	Params: str = A Punycode-encoded string to be decoded into a UTF-encoded string
	Returns: A UTF-encoded string decoded from Punycode
	Throws:
		PunycodeException if an internal error occured
		InvalidPunycodeException if an invalid Punycode string was passed
*/
S punyDecode(S)(in S str) @safe pure
if (isSomeString!S)
{
	import std.string : lastIndexOf;
	
	static uint decodeDigit(dchar c)
	{
		if (c.isUpper) return c - 'A';
		if (c.isLower) return c - 'a';
		if (c.isDigit) return c - '0' + 26;
		throw new InvalidPunycodeException("Invalid Punycode");
	}
	
	bool arithmeticOverflow;
	
	enforce!PunycodeException(str.length <= uint.max);
	enforce!InvalidPunycodeException(str.all!isASCII, "Invalid Punycode");

	dchar[] ret; //REVIEW: Why is this not an Appender?
	dchar n = initialN;
	uint i = 0;
	uint bias = initialBias;
	dstring dstr = str.to!dstring;
	immutable ptrdiff_t delimiterIndex = dstr.lastIndexOf('-');
	if (delimiterIndex != -1)
		ret = dstr[0 .. delimiterIndex].dup;
	ptrdiff_t idx = (delimiterIndex == -1 || delimiterIndex == 0) ? 0 : delimiterIndex + 1;
	while (idx < dstr.length)
	{
		immutable uint oldi = i;
		uint w = 1;
		for (uint k = base;;k += base)
		{
			enforce!InvalidPunycodeException(idx < dstr.length); //REVIEW: Can this be moved outside of the loop?
			immutable uint digit = decodeDigit(dstr[idx]);
			idx++;
			i = addu(i, digit * w, arithmeticOverflow);
			immutable t = k <= bias ? tmin :
				k >= bias + tmax ? tmax : k - bias;
			if (digit < t) break;
			w = mulu(w, base - t, arithmeticOverflow);
			enforce!PunycodeException(!arithmeticOverflow, "Arithmetic overflow");
		}
		//enforce!PunycodeException(ret.length < uint.max-1, "Arithmetic overflow"); //REVIEW: I do not believe this is necessary.
		bias = adaptBias(i - oldi, cast(uint) ret.length + 1, oldi == 0);
		n = addu(n, i / (ret.length + 1), arithmeticOverflow);
		enforce!PunycodeException(!arithmeticOverflow, "Arithmetic overflow");
		i %= ret.length + 1;
		(() @trusted => ret.insertInPlace(i, n))();
		i++;
	}
	return ret.to!S;
}

///
@safe pure
unittest
{
	assert(punyDecode("maana-pta") == "mañana");
}

@safe pure
unittest
{
	static void assertConvertible(S)(S plain, S punycode)
	{
		assert(punyEncode(plain) == punycode);
		assert(punyDecode(punycode) == plain);
	}
	assertConvertible("", "");
	assertConvertible("ASCII0123", "ASCII0123-");
	assertConvertible("Punycodeぴゅにこーど", "Punycode-p73grhua1i6jv5d");
	assertConvertible("Punycodeぴゅにこーど"w, "Punycode-p73grhua1i6jv5d"w);
	assertConvertible("Punycodeぴゅにこーど"d, "Punycode-p73grhua1i6jv5d"d);
	assertConvertible("ぴゅにこーど", "28j1be9azfq9a");
	assertConvertible("他们为什么不说中文", "ihqwcrb4cv8a8dqg056pqjye");
	assertConvertible("☃-⌘", "--dqo34k");
	assertConvertible("-> $1.00 <-", "-> $1.00 <--");
	assertThrown!InvalidPunycodeException(punyDecode("aaa-*"));
	assertThrown!InvalidPunycodeException(punyDecode("aaa-p73grhua1i6jv5dd"));
	assertThrown!InvalidPunycodeException(punyDecode("ü-"));
	assert(collectExceptionMsg(punyDecode("aaa-99999999")) == "Arithmetic overflow");
}

///	Exception thrown if there was an internal error when encoding or decoding punycode.
class PunycodeException : Exception
{
	import std.exception : basicExceptionCtors;
    mixin basicExceptionCtors;
}

/// Exception thrown if supplied punycode is invalid, and therefore cannot be decoded.
class InvalidPunycodeException : PunycodeException
{
	import std.exception : basicExceptionCtors;
    mixin basicExceptionCtors;
}

private uint adaptBias(uint delta, in uint numpoints, in bool firsttime) @safe @nogc pure nothrow
{
	uint k;
	delta = firsttime ? delta / damp : delta / 2;
	delta += delta / numpoints;
	while (delta > ((base - tmin) * tmax) / 2)
	{
		delta /= base - tmin;
		k += base;
	}
	return k + (base - tmin + 1) * delta / (delta + skew);
}
