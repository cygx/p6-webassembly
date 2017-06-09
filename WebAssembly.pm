unit module WebAssembly;

enum Type (
    :i32(0x7f),
    :i64(0x7e),
    :f32(0x7d),
    :f64(0x7c),
    :anyfunc(0x70),
    :func(0x60),
    :emptyblock(0x40),
);

sub pairup($_) { (my uint $ = $_) => $_ }

BEGIN my %ALL{Int} is default(Nil) = Type::.values.map(&pairup);
BEGIN my %VALUES{Int} is default(Nil) = (i32, i64, f32, f64).map(&pairup);

multi gettype($byte) { %ALL{$byte} }
multi gettype($byte, :$value_type!) { %VALUES{$byte} }
multi gettype($byte, :$func_type!) { $byte == func ?? func !! Nil }
multi gettype($byte, :$elem_type!) { $byte == anyfunc ?? anyfunc !! Nil }

class FuncType {
    has $.param_count;
    has @.param_types;
    has $.return_count;
    has $.return_type;
}

class GlobalType {
    has $.content_type;
    has $.mutability;
}

class TableType {
    has $.element_type;
    has $.limits;
}

class MemoryType {
    has $.limits;
}

class ResizableLimits {
    has $.flags;
    has $.initial;
    has $.maximum;
}

class Section {
    has $.id;
    has $.payload_len;
}

class CustomSection is Section {
    has $.name_len;
    has $.name;
    has $.payload_data;
}

class BlobStream { ... }

class Stream {
    has uint $!mark;

    method get($) { !!! }
    method getbyte { !!! }
    method getpos { !!! }

    method mark {
        $!mark = self.getpos;
        self;
    }

    method offset {
        self.getpos - $!mark;
    }

    proto method new(|) {*}
    multi method new(blob8 $blob) { BlobStream.bless(:$blob) }

    proto method read(|) {*}

    multi method read($n) {
        my $blob = self.get($n);
        POST $blob.elems == $n;
        $blob;
    }

    multi method read(:$uint8!) {
        self.getbyte;
    }

    multi method read(:$uint16!) {
        self.getbyte +| self.getbyte +< 8;
    }

    multi method read(:$uint32!) {
        self.getbyte
        +| self.getbyte +< 8
        +| self.getbyte +< 16
        +| self.getbyte +< 24;
    }

    multi method read(:$varuint!) {
        my uint64 $value;
        my uint $shift;
        my uint8 $byte;

        loop {
            $byte = self.getbyte;
            $value = $value +| ($byte +& 0x7f) +< $shift;
            last unless $byte +& 0x80;
            $shift = $shift + 7;
        }

        $value;
    }

    multi method read(:$varint!) {
        my int64 $value;
        my uint $shift;
        my uint8 $byte;

        repeat while $byte +& 0x80 {
            $byte = self.getbyte;
            $value = $value +| ($byte +& 0x7f) +< $shift;
            $shift = $shift + 7;
        }

        $shift < 64 && ($byte +& 0x40)
            ?? $value +| -(1 +< $shift)
            !! $value;
    }

    proto method parse(|) {*}

    multi method parse($bits, :$varuint!) {
        $_ < (1 +< $bits) ?? $_ !! Nil
            given self.read(:varuint);
    }

    multi method parse(:$magic_number!) {
        self.read(:uint32) == 0x6d736100 ?? 0x6d736100 !! Nil;
    }

    multi method parse(:$version!) {
        self.read(:uint32) == 1 ?? 1 !! Nil;
    }

    multi method parse(:$value_type!) {
        gettype(self.getbyte, :value_type)
    }

    multi method parse(:$elem_type!) {
        gettype(self.getbyte, :elem_type)
    }

    multi method parse(:$func_type!) {
        gettype(self.getbyte, :func_type)
        andthen my $param_count = self.parse(:varuint, 32)
        andthen my @param_types = (self.parse(:value_type) //
                                    return Nil) xx $param_count
        andthen my $return_count = self.parse(:varuint, 1)
        andthen $return_count && my $return_type = self.parse(:value_type)
        andthen FuncType.new(:$param_count, :@param_types, :$return_count, :$return_type)
        orelse Nil;
    }

    multi method parse(:$global_type!) {
        my $content_type = gettype(self.getbyte, :value_type)
        andthen my $mutability = self.parse(:varuint, 1)
        andthen GlobalType.new(:$content_type, :$mutability)
        orelse Nil;
    }

    multi method parse(:$table_type!) {
        my $element_type = self.parse(:elem_type)
        andthen my $limits = self.parse(:resizable_limits)
        andthen TableType.new(:$element_type, :$limits)
        orelse Nil;
    }

    multi method parse(:$memory_type!) {
        my $limits = self.parse(:resizable_limits)
        andthen MemoryType.new(:$limits)
        orelse Nil;
    }

    multi method parse(:$resizable_limits!) {
        my $flags = self.parse(:varuint, 1)
        andthen my $initial = self.parse(:varuint, 32)
        andthen $flags && my $maximum = self.parse(:varuint, 32)
        andthen ResizableLimits.new(:$flags, :$initial, :$maximum)
        orelse Nil;
    }

    multi method parse(:$section!) {
        my $id = self.parse(:varuint, 7)
        andthen my $payload_len = self.parse(:varuint, 32)
        andthen do given $id {
            # custom section
            when 0 {
                self.mark;
                my $name_len = self.parse(:varuint, 32)
                andthen my $name = ((try .decode) given self.read($name_len))
                andthen my $payload_data = self.read($payload_len - self.offset)
                andthen CustomSection.new(:$id, :$name_len, :$name, :$payload_data)
                orelse Nil;
            }

            default { Nil }
        }
    }
}

class BlobStream is Stream {
    has blob8 $.blob;
    has uint $.pos;
    method get($n) {
        LEAVE $!pos += $n;
        $!blob.subbuf($!pos, $n);
    }
    method getbyte { $!blob[$!pos++] }
    method getpos { $!pos }
}
