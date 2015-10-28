perl6-PDF-Tools
===============

## Overview

This module provides basic tools for PDF Manipulation, including:
- `PDF::Reader` - for indexed random access to PDFs
- `PDF::Storage::Filter` - a collection of standard PDF decoding and encoding tools for PDF data streams
- `PDF::Storage::Serializer` - data marshalling utilies for the preparation of full or incremental updates
- `PDF::Writer` - for the creation or update of PDFs
- `PDF::DAO` - an intermediate Data Access and Object representation layer (<a href="https://en.wikipedia.org/wiki/Data_access_object">DAO</a>) to PDF data structures.

Features of this tool-kit include:

- index based reading from PDF, with lazy loading of objects
- lazy incremental updates
- JSON interoperability
- high level data access via tied Hashes and Arrays
- a type system for mapping PDF internal structures to Perl 6 objects

Note: This is a low-to-medium level module. For higher level PDF manipulation, please see <a href="https://github.com/p6-pdf/perl6-PDF-DOM">PDF::DOM</a> (under construction).

## Example Usage

To create a one page PDF that displays 'Hello, World!'.

```
#!/usr/bin/env perl6
# creates t/helloworld.pdf
use v6;
use PDF::DAO;
use PDF::DAO::Doc;

sub prefix:</>($name){ PDF::DAO.coerce(:$name) };

my $doc = PDF::DAO::Doc.new;
my $catalog  = $doc.Root          = { :Type(/'Catalog') };
my $outlines = $catalog<Outlines> = { :Type(/'Outlines'), :Count(0) };
my $pages    = $catalog<Pages>    = { :Type(/'Pages'), :MediaBox[0, 0, 420, 595] };

$pages<Resources><Procset> = [ /'PDF', /'Text'];
$pages<Resources><Font><F1> = {
        :Type(/'Font'),
        :Subtype(/'Type1'),
        :BaseFont(/'Helvetica'),
        :Encoding(/'MacRomanEncoding'),
    };

$pages<Kids> = [ { :Type(/'Page') }, ];
$pages<Count> = + $pages<Kids>;
my $page = $pages<Kids>[0];
$page<Parent> = $pages;

$page<Contents> = PDF::DAO.coerce( :stream{ :decoded("BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET" ) } );

my $info = $doc.Info = {};
$info.CreationDate = DateTime.new( :year(2015), :month(12), :day(25) );
$info.Author = 'PDF-Tools/t/helloworld.t';

$doc.save-as: 't/helloworld.pdf';
```

Then to update the PDF, adding another page:

```
use v6;
use PDF::DAO::Doc;

my $doc = PDF::DAO::Doc.open: 't/helloworld.pdf';

my $catalog = $doc<Root>;
my $Parent = $catalog<Pages>;
my $Contents = PDF::DAO.coerce( :stream{ :decoded("BT /F1 16 Tf  90 250 Td (Goodbye for now!) Tj ET" ) } );
$Parent<Kids>.push: { :Type(/'Page'), :$Parent, :$Contents };
$Parent<Count>++;

my $info = $doc.Info //= {};
$info.ModDate = DateTime.now;
$doc.update;
```

## Description

A PDF file consists of data structures, including dictionarys (hashs) arrays, numbers and strings, plus streams
for holding data such as images, fonts and general content.

PDF files are also indexed for random access and may also have filters for stream compression and overall encryption.

They have a reasonably well specified structure. The document structure starts from
a `Root` entry in the outermost trailer dictionary.

This module is based on the <a href='http://www.adobe.com/content/dam/Adobe/en/devnet/acrobat/pdfs/pdf_reference_1-7.pdf'>PDF Reference version 1.7<a> specification. It implements syntax, basic data-types and serialization rules as described in the first four chapters of the specification.

Read and write access to data structures is via direct manipulation of tied arrays and hashes. The details
of serialization and data representation mostly remain hidden.

`PDF::DAO` also provides a set of class builder utilities to enable an even higher level of abstract classes.

This is put to work in the companion module <a href="https://github.com/p6-pdf/perl6-PDF-DOM">PDF::DOM</a> (under construction), which contains a much more detailed set of classes to implement much of the remainder of the PDF specification.

## Data Access Objects

`PDF::DAO` is roughly equivalent to an <a href="https://en.wikipedia.org/wiki/Object-relational_mapping">ORM</a> in that it provides the ability to define and map Perl 6 classes to PDF structures whilst hiding details of serialization and internal representations.

The following outlines the setup, from scratch, of document mapped classes with root `MyPDF::Catalog`.
```
use PDF::DAO::Tie;
use PDF::DAO::Type;
use PDF::DAO::Dict;

class My::Delegator is PDF::DAO::Delegator {
    method class-paths {<MyPDF PDF::DAO::Type>}
}

PDF::DAO.delegator = My::Delegator;

class MyPDF::Pages
    is PDF::DAO::Dict
    does PDF::Oject::Type {

    has MyPDF::Page @.Kids is entry(:required, :indirect);
}

class MyPDF::Catalog
    is PDF::DAO::Dict
    does PDF::DAO::Type {

    # see [PDF 1.7 TABLE 3.25 Entries in the catalog dictionary]
    use PDF::DAO::Name;
    has PDF::DAO::Name $.Version is entry;        #| (Optional; PDF 1.4) The version of the PDF specification to which the document conforms (for example, /1.4) 
    has MyPDF::Pages $.Pages is entry(:required, :indirect); #| (Required; must be an indirect reference) The page tree node
    # ... etc
}
```
if we then say
```
my $Catalog = PDF::DAO.coerce: { :Type( :name<Catalog> ),
                                 :Version( :name<PDF>),
                                 :Pages{ :Type{ :name<Pages> }, :Kids[], :Count(0) } };

```
`$Catalog` is coerced to type `MyPDF::Catalog`.
- `$Catalog.Pages` will autoload and Coerce to type `MyPDF::Pages`
- If that should fail (and there's no `PDF::DAO::Type::Pages` class), it falls-back to a plain `PDF::DAO::Dict` object.

## Datatypes and Coercian

The `PDF::DAO` namespace provides basic data-type classes for the representation and manipulation of PDF Objects.

```
use PDF::DAO::Stream;
my %dict = :Filter( :name<ASCIIHexDecode> );
my $obj-num = 123;
my $gen-num = 4;
my $decoded = "100 100 Td (Hello, world!) Tj";
my $stream-obj = PDF::DAO::Stream.new( :$obj-num, :$gen-num, :$dict, :$decoded );
say $stream.obj.encoded;
```

`PDF::DAO.coerce` is a method for the construction of objects.

It is used internally to build objects from parsed AST data, e.g.:

```
use v6;
use PDF::Grammar::Doc;
use PDF::Grammar::Doc::Actions;
use PDF::DAO;
my $actions = PDF::Grammar::Doc::Actions.new;
PDF::Grammar::Doc.parse("<< /Type /Pages /Count 1 /Kids [ 4 0 R ] >>", :rule<object>, :$actions)
    or die "parse failed";
my $ast = $/.ast;

say '#'~$ast.perl;
#:dict({:Count(:int(1)), :Kids(:array([:ind-ref([4, 0])])), :Type(:name("Pages"))})

my $object = PDF::DAO.coerce( %$ast );

say '#'~$object.WHAT.gist;
#(PDF::DAO::Dict)

say '#'~$object.perl;
#{:Count(1), :Kids([:ind-ref([4, 0])]), :Type("Pages")}

say '#'~$object<Type>;
#(Str+{PDF::DAO::Name})

say '#'~$object<Type>.WHAT.gist;
#{:Count(1), :Kids([:ind-ref([4, 0])]), :Type("Pages")}
```
`PDF::DAO.coerce` method is also used to construct new objects from application data.

In many cases, AST tags will coerce if omitted. E.g. we can use `1`, instead of `:int(1)`:
```
# using explicit AST tags
my $object2 = PDF::DAO.coerce({ :Type( :name<Pages> ),
                                :Count(:int(1)),
                                :Kids( :array[ :ind-ref[4, 0] ) ] });

# same but with a casting from native typs
my $object3 = PDF::DAO.coerce({ :Type( :name<Pages> ),
                                :Count(1),
                                :Kids[ :ind-ref[4, 0] ] });
say '#'~$object2.perl;

```

A table of Object types and coercements follows:

*AST Tag* | Object Role/Class | *Perl 6 Type Coercian | PDF Example | Description |
--- | --- | --- | --- | --- |
 `array` | PDF::DAO::Array | Array | `[ 1 (foo) /Bar ]` | array objects
`bool` | PDF::DAO::Bool | Bool | `true`
`int` | PDF::DAO::Int | Int | `42`
`literal` | PDF::DAO::ByteString (literal) | Str | `(hello world)`
`literal` | PDF::DAO::DateString | DateTime | `(D:199812231952-08'00')`
`hex-string` | PDF::DAO::ByteString (hex-string) | | `<736E6F6f7079>`
`dict` | PDF::DAO::Dict | Hash | `<< /Length 42 /Apples(oranges) >>` | abstract class for dictionary based indirect objects. Root Object, Catalog, Pages tree etc.
`name` | PDF::DAO::Name | | `/Catalog`
`null` | PDF::DAO::Null | Any | `null`
`real` | PDF::DAO::Real | Numeric | `3.14159`
`stream`| PDF::DAO::Stream | | | abstract class for stream based indirect objects - base class from Xref and Object streams, fonts and general content.

`PDF::DAO` also provides a few essential derived classes:

*Class* | *Base Class* | *Description*
--- | --- | --- |
PDF::DAO::Doc | PDF::DAO::Dict | the absolute root of the document - the trailer dictionary
PDF::DAO::Type::Encrypt | PDF::DAO::Dict | PDF Encryption/Permissions dictionary
PDF::DAO::Type::ObjStm | PDF::DAO::Stream | PDF 1.5+ Object stream (holds compressed objects)
PDF::DAO::Type::XRef | PDF::DAO::Stream | PDF 1.5+ Cross Reference stream

## Reading and Writing of PDF files:

`PDF::DAO::Doc` is a base class for loading, editing and saving documents in PDF, FDF and other related formats.

- `my $doc = PDF::DAO::Doc.open("mydoc.pdf" :repair)`
 Opens an input `PDF` (or `FDF`) document.
  - `:!repair` causes the read to load only the trailer dictionary and cross reference tables from the tail of the PDF (Cross Reference Table or a PDF 1.5+ Stream). Remaining objects will be lazily loaded on demand.
  - `:repair` causes the reader to perform a full scan, ignoring and recalculating the cross reference stream/index and stream lengths. This can be handy if the PDF document has been hand-edited.

- `$doc.update`
This performs an incremental update to the input pdf, which must be indexed `PDF` (not applicable to
PDF's opened with `:repair`, FDF or JSON files). A new section is appended to the PDF that
contains only updated and newly created objects. This method can be used as a fast and efficient way to make
small updates to a large existing PDF document.

- `$doc.save-as("mydoc-2.pdf", :compress, :rebuild)`
Saves a new document, including any updates. Options:
  - `:compress` - compress objects for minimal size
  - `:!compress` - uncompress objects for human redability
  - `:rebuild` - discard any unreferenced objects. reunumber remaining objects. It may be a good idea to rebuild a PDF Document, that's been incrementally updated a number of times.

Note that the `:compress` and `:rebuild` options are a trade-off. The document may take longer to save, however file-sizes and the time needed to reopen the document may improve.

- `$doc.save-as("mydoc.json", :compress, :rebuild); my $doc2 = $doc.open("mydoc.json")`
Documents can also be saved and restored from an intermediate `JSON` representation. This can
be handy for debugging, analysis and/or ad-hoc patching of PDF files. Beware that
saving and restoring to `JSON` is somewhat slower than save/restore to `PDF`.

### See also:
- `bin/pdf-rewriter.pl [--repair] [--rebuild] [--compress] [--uncompress] [--dom] <pdf-or-json-file-in> <pdf-or-json-file-out>`
This script is a thin wrapper for the `PDF::DAO::Doc` `.open` and `.save-as` methods. It can typically be used to uncompress a PDF for readability and/or repair a PDF who's cross-reference index or stream lengths have become invalid.

## Reading PDF files

The `PDF::Reader` `.open` method oads a PDF index (cross reference table and/or stream). The document can then be access randomly via the
`.ind.obj(...)` method.

The document can be traversed by dereferencing Array and Hash objects. The reader will load indirect objects via the index, as needed. 

```
use PDF
$reader.open( 't/helloworld.pdf' );

# objects can be directly fetched by object-number and generation-number:
$page1 = $reader.ind-obj(4, 0).object;

# Hashs and arrays are tied. This is usually more conveniant for navigating
my $doc = $reader.trailer<Root>;
my $page1 = $doc<Pages><Kids>[0];

# Tied objects can also be updated directly.
$pdf<Info><Creator> = PDF::DAO.coerce( :name<t/helloworld.t> );
```

## Decode Filters

Filters are used to compress or decompress stream data in objects of type `PDF::DAO::Stream`. These are implemented as follows:

*Filter Name* | *Short Name* | Filter Class
--- | --- | ---
ASCIIHexDecode  | AHx | PDF::Storage::Filter::ASCIIHex
ASCII85Decode   | A85 | PDF::Storage::Filter::ASCII85
CCITTFaxDecode  | CCF | _NYI_
Crypt           |     | _NYI_
DCTDecode       | DCT | _NYI_
FlateDecode     | Fl  | PDF::Storage::Filter::Flate
LZWDecode       | LZW | PDF::Storage::Filter::LZW
JBIG2Decode     |     | _NYI_
JPXDecode       |     | _NYI_
RunLengthDecode | RL  | PDF::Storage::Filter::RunLength

Input to all filters is strings, with characters in the range \x0 ... \0xFF. latin-1 encoding is recommended to enforce this.

Each file has `encode` and `decode` methods. Both return latin-1 encoded strings.

 ```
 my $encoded = PDF::Storage::Filter.encode( :dict{ :Filter<RunLengthEncode> },
                                            "This    is waaay toooooo loooong!");
 say $encoded.chars;
 ```

## Serialization

PDF::Storage::Serializer constructs AST for output by PDF::Writer. It can create full PDF bodies, or just changes for in-place incremental update to a PDF.

In place edits are particularly effective for making small changes to large PDF's, when we can avoid loading large unmodified portions of the PDF.

````
my $serializer = PDF::Storage::Serializer.new;
my $body = $serializer.body( $reader, :updates );
```

PDF::Writer then converts the AST back to a PDF byte image, with a rebulilt cross reference index.

```
my $offset = $reader.input.chars + 1;
my $prev = $body<trailer><dict><Prev>.value;
my $writer = PDF::Writer.new( :$offset, :$prev );
my $new-body = "\n" ~ $writer.write( :$body );

```

## See also

- [PDF::Grammar](https://github.com/p6-pdf/perl6-PDF-Grammar) - base grammars for PDF parsing
- [PDF::DOM](https://github.com/p6-pdf/perl6-PDF-DOM) - PDF Document Object Model (under construction)

## Development Status

Under construction (not yet released to Perl 6 ecosystem)
- Highest tested Rakudo version: `perl6 version 2015.10-49-ga333147 built on MoarVM version 2015.10`
- Encryption is NYI.


