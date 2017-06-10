unit package WebAssembly;

my enum Type is export (
    :i32(0x7f),
    :i64(0x7e),
    :f32(0x7d),
    :f64(0x7c),
    :anyfunc(0x70),
    :func(0x60),
    :emptyblock(0x40),
);

my enum ExternalKind is export (
    :Function(0),
    :Table(1),
    :Memory(2),
    :Global(3),
);

proto gettype($, *%) is export {*}
multi gettype(0x7f, :$value_type!) { i32 }
multi gettype(0x7e, :$value_type!) { i64 }
multi gettype(0x7d, :$value_type!) { f32 }
multi gettype(0x7c, :$value_type!) { f64 }
multi gettype(0x70, :$elem_type!) { anyfunc }
multi gettype(0x60, :$func_type!) { func }
multi gettype($, *%) { Nil }

my class FuncType is export {
    has $.param_count;
    has @.param_types;
    has $.return_count;
    has $.return_type;
}

my class GlobalType is export {
    has $.content_type;
    has $.mutability;
}

my class TableType is export {
    has $.element_type;
    has $.limits;
}

my class MemoryType is export {
    has $.limits;
}

my class ResizableLimits is export {
    has $.flags;
    has $.initial;
    has $.maximum;
}

my class ImportEntry is export {
    has $.module;
    has $.field;
    has $.kind;
    has $.type;
}

my class ExportEntry is export {
    has $.field;
    has $.kind;
    has $.index;
}

my class GlobalVariable is export {
    has $.type;
    has $.init;
}

my class InitExpr is export {}

my class DataSegment is export {
    has $.index;
    has $.offset;
    has $.size;
    has $.data;
}

my class LocalEntry is export {
    has $.count;
    has $.type;
}

my class FunctionBody is export {
    has $.body_size;
    has @.locals;
    has $.code;
    has $.index;
    method local_count { @!locals.elems }
}

my class Section is export {
    has $.id;
    has $.payload_len;
}

my class Section::Common is Section {
    has @.entries;
    method count { @!entries.elems }
}

my class CustomSection is Section is export {
    has $.name;
    has $.payload_data;
}

my class StartSection is Section is export {
    has $.index;
}

my class TypeSection is Section::Common is export {}
my class ImportSection is Section::Common is export {}
my class FunctionSection is Section::Common is export {}
my class TableSection is Section::Common is export {}
my class MemorySection is Section::Common is export {}
my class GlobalSection is Section::Common is export {}
my class ExportSection is Section::Common is export {}
my class ElementSection is Section::Common is export {}
my class CodeSection is Section::Common is export {}
my class DataSection is Section::Common is export {}
