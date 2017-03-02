# Punycode.d

* Author: Shotaro Yamada (Sinkuu), with minor changes made by Jonathan M. Wilbur
* Copyright: Shotaro Yamada
* License: [Boost License 1.0](http://www.boost.org/LICENSE_1_0.txt)
* Date: February 27th, 2017
* Version: 1.0.1

A Punycode encoder and decoder based on the original implementation in [RFC 3492](https://www.ietf.org/rfc/rfc3492.txt), and [the JavaScript implementation by Mathias Bynens](https://github.com/bestiejs/punycode.js). Originally written by Shotaro Yamada (@sinkuu), then very slightly improved by Jonathan M. Wilbur (@jonathanwilbur). Punycode is primarily used for converting URIs or IRIs containing non-ASCII characters into URIs or IRIs that are entirely ASCII, and vice versa. This is done because DNS is based on ASCII, so all DNS requests must be converted to ASCII before they can be processed.

## Usage

There are just two functions: punyEncode() and punyDecode().

### Encoding

Encode strings with the punyEncode() function:

```d
string unencoded = "mañana"; // a UTF-encoded string (notice the non-ASCII 'ñ')
string encoded = punyEncode(unencoded); // encoded is now "maana-pta" (purely ASCII)
assert(encoded == "maana-pta"); // passes
```

### Decoding

Decode Punycode-encoded strings with the punyDecode() function:

```d
string encoded = "maana-pta"; // a Punycode-encoded string (purely ASCII)
string decoded = punyDecode(encoded); // decoded is now "mañana" (UTF)
assert(decoded == "mañana"); // passes
```

### Rationale

I am submitting this to the D Standard Library (Phobos) because because I believe it is a suitable candidate for a standard library module, on these grounds:

1. It is critical to Uniform Resource Identifiers (URIs), which are ubiquitous, and are themselves critical for many programs.
2. Phobos already has a module for Uniform Resource Identifiers: std.uri, yet no functionality for Punycode.
3. It is critical to the Domain Name System (DNS), which is also ubiquitous, and itself critical for many programs.
4. There are probably a few other ways that nobody has thought of for encoding and decoding Punycode, but only one way is specified clearly as an example implementation in the original RFC that specifies Punycode. This module, is based upon the original suggested implementation in RFC 3492, and there is little--if any--reason why a developer would prefer an alternative implementation.

### Future Intent

I will be submitting this to the D Standard Library. If it does not get accepted
in principle (rather than in implementation), it will be published as a DUB package, 
and also incorporated into a D URL / URI Library, which will be submitted to the 
D Standard Library.

### See Also

* [Wikipedia: Punycode](https://en.wikipedia.org/wiki/Punycode)
* [RFC 3492](https://www.ietf.org/rfc/rfc3492.txt)
* [The JavaScript implementation by Mathias Bynens](https://github.com/bestiejs/punycode.js)

### Contact

If you have any commentary, criticism, or ideas relating to the code, please 
comment on it in GitHub. If you have other questions, please email me at 
[jwilbur@jwilbur.info](mailto:jwilbur@jwilbur.info).
