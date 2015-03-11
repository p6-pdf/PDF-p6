use v6;
use Test;

plan 11;

use PDF::Tools::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = 't/pdf/ind-obj-ObjStm-Flate.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Tools::IndObj.new( |%$ast, :$input );
isa_ok $ind-obj.object, ::('PDF::Object')::('Type::ObjStm');

my $objstm;
lives_ok { $objstm = $ind-obj.object.decode }, 'basic content decode - lives';

my $expected-objstm = [
    [16, "<</BaseFont/CourierNewPSMT/Encoding/WinAnsiEncoding/FirstChar 111/FontDescriptor 15 0 R/LastChar 111/Subtype/TrueType/Type/Font/Widths[600]>>",
    ],
    [17, "<</BaseFont/TimesNewRomanPSMT/Encoding/WinAnsiEncoding/FirstChar 32/FontDescriptor 14 0 R/LastChar 32/Subtype/TrueType/Type/Font/Widths[250]>>",
    ],
    ];

is_deeply $objstm, $expected-objstm, 'decoded index as expected';
my $objstm-recompressed = $ind-obj.object.encode;

my $ast2;
lives_ok { $ast2 = $ind-obj.ast }, '$.ast - lives';

my $ind-obj2 = PDF::Tools::IndObj.new( |%$ast2 );
my $objstm-roundtrip = $ind-obj2.object.decode( $objstm-recompressed );

is_deeply $objstm, $objstm-roundtrip, 'encode/decode round-trip';

my $objstm-new = ::('PDF::Object')::('Type::ObjStm').new(:dict{}, :decoded[[10, '<< /Foo (bar) >>'], [11, '[ 42 true ]']] );
lives_ok {$objstm-new.encode( :check )}, '$.encode( :check ) - with valid data lives';
is $objstm-new.Type, 'ObjStm', '$xref.new .Name auto-setup';
is $objstm-new.N, 2, '$xref.new .N auto-setup';
is $objstm-new.First, 11, '$xref.new .First auto-setup';

my $invalid-decoding =  [[10, '<< /Foo wtf!! (bar) >>'], [11, '[ 42 true ]']];
lives_ok {$objstm-new.encode( $invalid-decoding) }, 'encoding invalid data without :check (lives)';
dies_ok {$objstm-new.encode( $invalid-decoding, :check) }, 'encoding invalid data without :check (dies)';

