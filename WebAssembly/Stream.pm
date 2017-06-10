unit package WebAssembly;
use WebAssembly::Sections;

my class BlobStream { ... }

class Stream is export {
    has uint $!mark;

    method get($) { !!! }
    method getbyte { !!! }
    method getpos { !!! }
    method hasmore { !!! }

    proto method new(|) {*}
    multi method new(blob8 $blob) { BlobStream.bless(:$blob) }

    method sections {
        self.parse(:magic_number) // fail "invalid magic number";
        self.parse(:version) // fail "unsupported version";
        gather loop { take self.parse(:section) // last }
    }

    method mark {
        $!mark = self.getpos;
        self;
    }

    method offset {
        self.getpos - $!mark;
    }

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

    proto method parse(|) { self.hasmore ?? {*} !! Nil }

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
        defined gettype(self.getbyte, :func_type)
        and defined my $param_count = self.parse(:varuint, 32)
        and defined my @param_types = (self.parse(:value_type) // return Nil) xx $param_count
        and defined my $return_count = self.parse(:varuint, 1)
        and defined $return_count && (my $return_type = self.parse(:value_type))
        and FuncType.new(:$param_count, :@param_types, :$return_count, :$return_type)
        or Nil;
    }

    multi method parse(:$global_type!) {
        defined my $content_type = gettype(self.getbyte, :value_type)
        and defined my $mutability = self.parse(:varuint, 1)
        and GlobalType.new(:$content_type, :$mutability)
        or Nil;
    }

    multi method parse(:$table_type!) {
        defined my $element_type = self.parse(:elem_type)
        and defined my $limits = self.parse(:resizable_limits)
        and TableType.new(:$element_type, :$limits)
        or Nil;
    }

    multi method parse(:$memory_type!) {
        defined my $limits = self.parse(:resizable_limits)
        and MemoryType.new(:$limits)
        or Nil;
    }

    multi method parse(:$resizable_limits!) {
        defined my $flags = self.parse(:varuint, 1)
        and defined my $initial = self.parse(:varuint, 32)
        and defined $flags && (my $maximum = self.parse(:varuint, 32))
        and ResizableLimits.new(:$flags, :$initial, :$maximum)
        or Nil;
    }

    multi method parse(:$external_kind!) {
        ExternalKind(self.read(:uint8)) // Nil;
    }

    multi method parse(:$import_entry!) {
        defined my $module_len = self.parse(:varuint, 32)
        and defined my $module_blob = self.read($module_len)
        and defined my $module = (try $module_blob.decode)
        and defined my $field_len = self.parse(:varuint, 32)
        and defined my $field_blob = self.read($field_len)
        and defined my $field = (try $field_blob.decode)
        and defined my $kind = self.parse(:external_kind)
        and defined my $type = (given $kind {
            when Function { self.parse(:varuint, 32) }
            when Table { self.parse(:table_type) }
            when Memory { self.parse(:memory_type) }
            when Global { self.parse(:global_type) }
        })
        and ImportEntry.new(:$module, :$field, :$kind, :$type)
        or Nil;
    }

    multi method parse(:$init_expr!) {
        while self.getbyte != 0x0b {}
        # todo
        42;
    }

    multi method parse(:$global_variable!) {
        defined my $type = self.parse(:global_type)
        and defined my $init = self.parse(:init_expr)
        and GlobalVariable.new(:$type, :$init)
        or Nil;
    }

    multi method parse(:$export_entry!) {
        defined my $field_len = self.parse(:varuint, 32)
        and defined my $field_blob = self.read($field_len)
        and defined my $field = (try $field_blob.decode)
        and defined my $kind = self.parse(:external_kind)
        and defined my $index = self.parse(:varuint, 32)
        and ExportEntry.new(:$field, :$kind, :$index)
        or Nil;
    }

    multi method parse(:$function_body!) {
        # todo
        defined my $body_size = self.parse(:varuint, 32)
        and defined self.read($body_size)
        and 42
        or Nil;
    }

    multi method parse(:$data_segment!) {
        defined my $index = self.parse(:varuint, 32)
        and defined my $offset = self.parse(:init_expr)
        and defined my $size = self.parse(:varuint, 32)
        and defined my $data = self.read($size)
        and DataSegment.new(:$index, :$offset, :$size, :$data)
        or Nil;
    }

    multi method parse(:$section!) {
        defined my $id = self.parse(:varuint, 7)
        and defined my $payload_len = self.parse(:varuint, 32)
        and do given $id {
            # custom section
            when 0 {
                self.mark;
                defined my $name_len = self.parse(:varuint, 32)
                and defined my $name_blob = self.read($name_len)
                and defined my $name = (try $name_blob.decode)
                and defined my $payload_data = self.read($payload_len - self.offset)
                and CustomSection.new(:$id, :$payload_len, :$name, :$payload_data)
                or Nil;
            }

            # type section
            when 1 {
                defined my $count = self.parse(:varuint, 32)
                and defined my @entries = (self.parse(:func_type) // return Nil) xx $count
                and TypeSection.new(:$id, :$payload_len, :@entries)
                or Nil;
            }

            # import section
            when 2 {
                defined my $count = self.parse(:varuint, 32)
                and defined my @entries = (self.parse(:import_entry) // return Nil) xx $count
                and ImportSection.new(:$id, :$payload_len, :@entries)
                or Nil;
            }

            # function section
            when 3 {
                defined my $count = self.parse(:varuint, 32)
                and defined my @entries = (self.parse(:varuint, 32) // return Nil) xx $count
                and FunctionSection.new(:$id, :$payload_len, :@entries)
                or Nil;
            }

            # table section
            when 4 {
                defined my $count = self.parse(:varuint, 32)
                and defined my @entries = (self.parse(:table_type) // return Nil) xx $count
                and TableSection.new(:$id, :$payload_len, :@entries)
                or Nil;
            }

            # memory section
            when 5 {
                defined my $count = self.parse(:varuint, 32)
                and defined my @entries = (self.parse(:memory_type) // return Nil) xx $count
                and MemorySection.new(:$id, :$payload_len, :@entries)
                or Nil;
            }

            # global section
            when 6 {
                defined my $count = self.parse(:varuint, 32)
                and defined my @entries = (self.parse(:global_variable) // return Nil) xx $count
                and GlobalSection.new(:$id, :$payload_len, :@entries)
                or Nil;
            }

            # export section
            when 7 {
                defined my $count = self.parse(:varuint, 32)
                and defined my @entries = (self.parse(:export_entry) // return Nil) xx $count
                and ExportSection.new(:$id, :$payload_len, :@entries)
                or Nil;
            }

            # start section
            when 8 {
                defined my $index = self.parse(:varuint, 32)
                and StartSection.new(:$index)
                or Nil;
            }

            # element section
            when 9 { die 'TODO' }

            # code section
            when 10 {
                defined my $count = self.parse(:varuint, 32)
                and defined my @entries = (self.parse(:function_body) // return Nil) xx $count
                and CodeSection.new(:$id, :$payload_len, :@entries)
                or Nil;
            }

            # data section
            when 11 {
                defined my $count = self.parse(:varuint, 32)
                and defined my @entries = (self.parse(:data_segment) // return Nil) xx $count
                and DataSection.new(:$id, :$payload_len, :@entries)
                or Nil;
            }

            default { die "illegal section $_" }
        }
    }
}

my class BlobStream is Stream {
    has blob8 $.blob;
    has uint $.pos;
    method hasmore { $!pos < $!blob.elems }
    method get($n) {
        LEAVE $!pos += $n;
        $!blob.subbuf($!pos, $n);
    }
    method getbyte { $!blob[$!pos++] }
    method getpos { $!pos }
}
