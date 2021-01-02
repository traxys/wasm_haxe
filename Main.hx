import haxe.io.BytesData;

class Main {
	static var input:Array<Int> = [0,97,115,109,1,0,0,0,1,13,3,96,1,127,1,127,96,1,127,0,96,0,0,2,15,1,3,101,110,118,7,112,117,116,99,104,97,114,0,0,3,4,3,1,0,2,4,5,1,112,1,1,1,5,3,1,0,2,6,8,1,127,1,65,128,136,4,11,7,19,2,6,109,101,109,111,114,121,2,0,6,95,115,116,97,114,116,0,3,10,244,2,3,141,1,1,14,127,35,128,128,128,128,0,33,1,65,16,33,2,32,1,32,2,107,33,3,32,3,36,128,128,128,128,0,32,3,32,0,54,2,12,32,3,40,2,12,33,4,2,64,2,64,32,4,13,0,12,1,11,32,3,40,2,12,33,5,65,10,33,6,32,5,32,6,109,33,7,32,7,16,129,128,128,128,0,32,3,40,2,12,33,8,65,10,33,9,32,8,32,9,111,33,10,65,48,33,11,32,10,32,11,106,33,12,32,12,16,128,128,128,128,0,26,11,65,16,33,13,32,3,32,13,106,33,14,32,14,36,128,128,128,128,0,15,11,198,1,1,23,127,35,128,128,128,128,0,33,1,65,16,33,2,32,1,32,2,107,33,3,32,3,36,128,128,128,128,0,65,1,33,4,32,3,32,0,54,2,8,32,3,40,2,8,33,5,32,5,33,6,32,4,33,7,32,6,32,7,76,33,8,65,1,33,9,32,8,32,9,113,33,10,2,64,2,64,32,10,69,13,0,65,1,33,11,32,3,32,11,54,2,12,12,1,11,32,3,40,2,8,33,12,65,1,33,13,32,12,32,13,107,33,14,32,14,16,130,128,128,128,0,33,15,32,3,40,2,8,33,16,65,2,33,17,32,16,32,17,107,33,18,32,18,16,130,128,128,128,0,33,19,32,15,32,19,106,33,20,32,3,32,20,54,2,12,11,32,3,40,2,12,33,21,65,16,33,22,32,3,32,22,106,33,23,32,23,36,128,128,128,128,0,32,21,15,11,27,1,2,127,65,20,33,0,32,0,16,130,128,128,128,0,33,1,32,1,16,129,128,128,128,0,15,11,0,42,4,110,97,109,101,1,35,4,0,7,112,117,116,99,104,97,114,1,10,112,114,105,110,116,95,117,105,110,116,2,3,102,105,98,3,6,95,115,116,97,114,116,0,38,9,112,114,111,100,117,99,101,114,115,1,12,112,114,111,99,101,115,115,101,100,45,98,121,1,5,99,108,97,110,103,6,49,48,46,48,46,48];

    static function main() {
		var wasm = new WasmBinary(Main.input);
		Sys.println("Module Info:");
		Sys.println("============");
		Sys.println("");
		wasm.info();

		var start = null;
		switch wasm.find_export("_start") {
			case Func(id): start = id;
			case x: throw 'Start is not a function: $x';
		};

		var inter = new WasmInterpreter(wasm);
		inter.execute_init(start);
    }
}

class Utils {
	public static function equals(a:Array<Int>, b:Array<Int>): Bool {
		if (a.length != b.length) {
			return false;
		}
		for (i in 0...a.length) {
			if (a[i] != b[i]) {
				return false;
			}
		}
		return true;
	}

	public static function readU(N:Int, bytes: Iterator<Int>): Int {
		var n = bytes.next();
		if (n < 128 && n < Math.pow(2, N)) {
			return n;
		} else {
			var m = Utils.readU(N-7, bytes);
			return 128 * m + (n - 128);
		}
	}

	public static function readS(N: Int, bytes: Iterator<Int>): Int {
		return Utils.readSStart(N, bytes.next(), bytes);
	}

	public static function readSStart(N: Int, start: Int, bytes: Iterator<Int>): Int {
		var n = start;
		if (n < 64 && n < Math.pow(2, N - 1)) {
			return n;
		} else if (64 <= n && n < 128 && n > 128 - Math.pow(2, N - 1)) {
			return n - 128;
		} else {
			var m = Utils.readS(N-7, bytes);
			return 128 * m + (n - 128);
		}
	}

	@:generic public static function readVec<T>(bytes: Iterator<Int>, parser: Iterator<Int>->T): Array<T> {
		var size = Utils.readU(32, bytes);
		return [for (_ in 0...size) parser(bytes)];
	}

	public static function parseValType(bytes: Iterator<Int>): ValType {
		switch bytes.next() {
			case 0x7f: return I32;
			case 0x7e: return I64;
			case 0x7d: return F32;
			case 0x7c: return F64;
			case _: throw "Unknown valtype";
		}
	}

	public static function readName(bytes: Iterator<Int>): String {
		var byteString = Utils.readVec(bytes, (x) -> x.next());
		var st = "";
		for (b in byteString) {
			st += String.fromCharCode(b);
		}
		return st;
	}

	public static function readMut(bytes: Iterator<Int>): Mut {
		switch bytes.next() {
			case 0x00: return Const;
			case 0x01: return Var;
			case _: throw "Unkown mut kind";
		}
	}

	public static function intBinOp<T>(lhs: WasmValue, rhs: WasmValue, f: (Int, Int) -> Int): WasmValue {
		switch [lhs, rhs] {
			case [I32(lhs), I32(rhs)]: return I32(f(lhs, rhs));
			case [I64(lhs), I64(rhs)]: return I64(f(lhs, rhs));
			case _: throw 'Invalid types in intBinOp: $lhs, $rhs';
		}
	}
	public static function floatBinOp<T>(lhs: WasmValue, rhs: WasmValue, f: (Float, Float) -> Float): WasmValue {
		switch [lhs, rhs] {
			case [F32(lhs), F32(rhs)]: return F32(f(lhs, rhs));
			case [F64(lhs), F64(rhs)]: return F64(f(lhs, rhs));
			case _: throw 'Invalid types in floatBinOp: $lhs, $rhs';
		}
	}
}

class Section {
	var size: Int;

	public function new(bytes: Iterator<Int>) {
		size = Utils.readU(32, bytes);
	}

	public function dummyRead(bytes: Iterator<Int>) {
		for(_ in 0...this.size) {
			bytes.next();
		}
	}
}

@:generic
class VecSection<T> extends Section {
	public var elements(default, null): Array<T>;

	public function new(bytes: Iterator<Int>, parser: Iterator<Int>->T) {
		super(bytes);
		elements = Utils.readVec(bytes, parser);
	}
}

enum ValType {
	I32;
	I64;
	F32;
	F64;
}

class FuncType {
	public var inputs(default, null): Array<ValType>;
	public var outputs(default, null): Array<ValType>;

	public function new(bytes: Iterator<Int>) {
		if (bytes.next() != 0x60) {
			throw "Invalid functype";
		}
		inputs = Utils.readVec(bytes, Utils.parseValType);
		outputs = Utils.readVec(bytes, Utils.parseValType);
	}

	public function toString() {
		var sig = "f(";

		for (v in inputs) {
			sig += v + ",";
		}
		sig += ") -> (";

		for (v in outputs) {
			sig += v + ",";
		}
		sig += ")";

		return sig;
	}
}

class Limit {
	var min: Int;
	var max: Int;

	public function new(bytes: Iterator<Int>) {
		switch bytes.next() {
			case 0x00:
				min = Utils.readU(32, bytes);
			case 0x01:
				min = Utils.readU(32, bytes);
				max = Utils.readU(32, bytes);
			case _:
				throw "Unknown limit kind";
		}
	}

	public function toString(): String {
		return '{min: ${min}, max: ${max}}';
	}
}

class Table {
	var limit:Limit;

	public function new(bytes: Iterator<Int>) {
		if (bytes.next() != 0x70) {
			throw "Table only allows funcref";
		}

		limit = new Limit(bytes);
	}

	public function toString(): String {
		return 'funcref (limit: ${limit})';
	}
}

class MemType {
	var limit:Limit;

	public function new(bytes: Iterator<Int>) {
		limit = new Limit(bytes);
	}

	public function toString(): String {
		return 'memlimit ${limit}';
	}
}

enum Mut {
	Const;
	Var;
}

class GlobalType {
	public var type(default, null): ValType;
	public var mut(default, null): Mut;

	public function new(bytes: Iterator<Int>) {
		type = Utils.parseValType(bytes);
		mut = Utils.readMut(bytes);
	}

	public function toString(): String {
		return '$mut $type';
	}
}

enum ImportDesc {
	FuncRef(ref: Int);
	Table(table: Table);
	Memory(mem: MemType);
	Global(global: GlobalType);
}

class Import {
	var mod: String;
	var name: String;
	public var desc(default, null): ImportDesc;

	public function new(bytes: Iterator<Int>) {
		mod = Utils.readName(bytes);
		name = Utils.readName(bytes);

		switch bytes.next() {
			case 0x00: desc = FuncRef(Utils.readU(32, bytes));
			case 0x01: desc = Table(new Table(bytes));
			case 0x02: desc = Memory(new MemType(bytes));
			case 0x03: desc = Global(new GlobalType(bytes));
			case _: throw "invalid import type";
		}
	}

	public function toString(): String {
		return '${mod}.${name} := ${desc}';
	}
}

enum ExportDesc {
	Func(ref: Int);
	Table(ref: Int);
	Mem(ref: Int);
	Global(ref: Int);
}

class Export {
	public var name(default, null): String;
	public var desc(default, null): ExportDesc;

	public function new(bytes: Iterator<Int>) {
		name = Utils.readName(bytes);

		var kind = bytes.next();
		var ref = Utils.readU(32, bytes);
		switch kind {
			case 0x00: desc = Func(ref);
			case 0x01: desc = Table(ref);
			case 0x02: desc = Mem(ref);
			case 0x03: desc = Global(ref);
			case _: throw "invalid export type";
		}
	}

	public function toString(): String {
		return 'export $name := $desc';
	}
}

class Locals {
	var n: Int;
	var type: ValType;

	public function new(bytes: Iterator<Int>) {
		n = Utils.readU(32, bytes);
		type = Utils.parseValType(bytes);
	}

	public function toString(): String {
		return '($type)^$n';
	}

	public function init(): Array<WasmValue> {
		var value = null;
		switch type {
			case I32: value = I32(0);
			case I64: value = I64(0);
			case F32: value = F32(0.0);
			case F64: value = F64(0.0);
		};
		return [for (i in 0...n) value];
	}
}

class Globals {
	public var type(default, null): GlobalType;
	public var init(default, null): Expr;

	public function new(bytes: Iterator<Int>) {
		type = new GlobalType(bytes);
		init = new BareExpr(bytes);
	}

	public function toString(): String {
		return '$type = $init';
	}
}


enum BlockType {
	Epsilon;
	ValType(t: ValType);
	TypeIdx(x: Int);
}

enum BlockInstrKind {
	Block(instrs: Expr);
	Loop(instrs: Expr);
	If(then: Expr, els: Expr);
}

class BlockInstr {
	var type: BlockType;
	public var instr(default, null): BlockInstrKind;

	static function readBlockType(bytes: Iterator<Int>): BlockType {
		switch bytes.next() {
			case 0x40: return Epsilon;
			case 0x7F: return ValType(I32);
			case 0x7e: return ValType(I64);
			case 0x7d: return ValType(F32);
			case 0x7c: return ValType(F64);
			case x: return TypeIdx(Utils.readSStart(33, x, bytes));
		}
	}

	static function readInstrKind(opcode: Int, bytes: Iterator<Int>): BlockInstrKind {
		var first = new Expr(bytes);
		var second = null;

		if (opcode == 0x04) {
			if (first.has_else) {
				second = new Expr(bytes);
			}
		} else if (first.has_else) {
			throw "Non if block finished by ElseEnd";
		}

		switch opcode {
			case 0x02: return Block(first);
			case 0x03: return Loop(first);
			case 0x04: return If(first, second);
			case x: throw 'Unknown block type: $x';
		}
	}

	public function new(opcode: Int, bytes: Iterator<Int>) {
		type = BlockInstr.readBlockType(bytes);
		instr = BlockInstr.readInstrKind(opcode, bytes);
	}
}

enum VarInstrKind {
	Get;
	Set;
	Tee;
}

class VarInstr {
	public var global(default, null): Bool;
	public var kind(default, null): VarInstrKind;
	public var index(default, null): Int;

	public function new(opcode: Int, bytes: Iterator<Int>) {
		index = Utils.readU(32, bytes);
		switch opcode {
			case 0x20:
				global = false;
				kind = Get;
			case 0x21:
				global = false;
				kind = Set;
			case 0x22:
				global = false;
				kind = Tee;
			case 0x23:
				global = true;
				kind = Get;
			case 0x24:
				global = true;
				kind = Set;
		}
	}
}

class MemArg {
	var a: Int;
	var o: Int;

	public function new(bytes: Iterator<Int>) {
		a = Utils.readU(32, bytes);
		o = Utils.readU(32, bytes);
	}
}

enum MemInstrKind {
	Load(location: MemArg);
	Store(location: MemArg);
	Size;
	Grow;
}

class MemInstr {
	var kind: MemInstrKind;
	var type: ValType;
	var signed: Bool;
	var bandwith: Int;

	public function new(opcode: Int, bytes: Iterator<Int>) {
		switch opcode {
			case 0x28 | 0x29 | 0x2A | 0x2B | 0x2C | 0x2D | 
				 0x2E | 0x2F | 0x30 | 0x31 | 0x32 | 0x33 |
				 0x34 | 0x35:
				kind = Load(new MemArg(bytes));
				switch opcode {
					case 0x28 | 0x2C | 0x2D | 0x2E | 0x2F:
						type = I32;
					case 0x29 | 0x30 | 0x31 | 0x32 | 0x33 | 0x34 | 0x35:
						type = I64;
					case 0x2A:
						type = F32;
					case 0x2B:
						type = F64;
				}
				switch opcode {
					case 0x2C | 0x2E | 0x30 | 0x32 | 0x34:
						signed = true;
					case 0x2D | 0x2F | 0x31 | 0x33 | 0x35:
						signed = false;
				}
				switch opcode {
					case 0x2C | 0x2D | 0x30 | 0x31:
						bandwith = 8;
					case 0x2E | 0x2F | 0x32 | 0x33:
						bandwith = 16;
					case 0x34 | 0x35 | 0x28:
						bandwith = 32;
					case 0x29:
						bandwith = 64;
				}
			case 0x36 | 0x37 | 0x38 | 0x39 | 0x3A | 0x3B |
				 0x3C | 0x3D | 0x3E:
				kind = Store(new MemArg(bytes));
				switch opcode {
					case 0x36 | 0x3A | 0x3B:
						type = I32;
					case 0x37 | 0x3C | 0x3D | 0x3E:
						type = I64;
					case 0x38:
						type = F32;
					case 0x39:
						type = F64;
				}
				switch opcode {
					case 0x3A | 0x3C:
						bandwith = 8;
					case 0x3D | 0x3B:
						bandwith = 16;
					case 0x36 | 0x3E:
						bandwith = 32;
					case 0x37:
						bandwith = 64;
				}
			case 0x3F:
				if (bytes.next() != 0x00) {
					throw "memory.size requires a zero byte";
				}
				kind = Size;
			case 0x40:
				if (bytes.next() != 0x00) {
					throw "memory.grow requires a zero byte";
				}
				kind = Grow;
		}
	}
}

enum Numeric {
	I64(val: Int);
	I32(val: Int);
	F32(val: Float);
	F64(val: Float);
	Generic(type: ValType, kind: NumericKind);
	Integer(i32: Bool, kind: IntNumeric);
	Floating(f32: Bool, kind: FloatNumeric);
}

enum NumericKind {
	Eqz;
	Eq;
	Ne;
	Cmp(signed: Bool, kind: CmpKind);
	Add;
	Sub;
	Mul;
	Div(signed: Bool);
}

enum CmpKind {
	Greater;
	Lesser;
	GreaterEqual;
	LesserEqual;
}

enum IntNumeric {
	Clz;
	Ctz;
	PopCnt;
	Rem(signed: Bool);
	And;
	Or;
	Xor;
	Shl;
	Shr(signed: Bool);
	Rotl;
	Rotr;
}

enum FloatNumeric {
	Abs;
	Neg;
	Ceil;
	Floor;
	Trunc;
	Nearest;
	Sqrt;
	Min;
	Max;
	CopySign;
}

enum Instr {
	Unreachable;
	Nop;
	Block(instr: BlockInstr);
	Br(label: Int);
	BrIf(label: Int);
	BrTable(labels: Array<Int>, l: Int);
	Return;
	Call(id: Int);
	CallIndirect(id: Int);
	Drop;
	Select;
	Var(instr: VarInstr);
	Mem(instr: MemInstr);
	Numeric(instr: Numeric);
	BlockEnd;
	ElseEnd;
}

class InstrReader {
	public static function readInstr(bytes: Iterator<Int>): Instr {
		var opcode = bytes.next();
		switch opcode {
			case 0x05: return ElseEnd;
			case 0x0B: return BlockEnd;
			case 0x00: return Unreachable;
			case 0x01: return Nop;
			case 0x02 | 0x03 | 0x04: return Block(new BlockInstr(opcode, bytes)); 
			case 0x0C: 
				var label = Utils.readU(32, bytes);
				return Br(label);
			case 0x0d:
				var label = Utils.readU(32, bytes);
				return BrIf(label);
			case 0x0e:
				var labels = Utils.readVec(bytes, (b) -> Utils.readU(32, b));
				var l = Utils.readU(32, bytes);
				return BrTable(labels, l);
			case 0x0F:
				return Return;
			case 0x10:
				var funcId = Utils.readU(32, bytes);
				return Call(funcId);
			case 0x11:
				var funcId = Utils.readU(32, bytes);
				if(bytes.next() != 0) {
					throw "Malformed Call Indirect";
				}
				return CallIndirect(funcId);
			case 0x1A:
				return Drop;
			case 0x1B:
				return Select;
			case 0x20 | 0x21 | 0x22 | 0x23 | 0x24:
				return Var(new VarInstr(opcode, bytes));
			case 0x28 | 0x29 | 0x2A | 0x2B | 0x2C | 0x2D | 
				 0x2E | 0x2F | 0x30 | 0x31 | 0x32 | 0x33 |
				 0x34 | 0x35 | 0x36 | 0x37 | 0x38 | 0x39 |
				 0x3A | 0x3B | 0x3C | 0x3D | 0x3E | 0x3F |
			     0x40:
				 return Mem(new MemInstr(opcode, bytes));
			case 0x41:
				return Numeric(I32(Utils.readS(32, bytes)));
			case 0x42:
				return Numeric(I64(Utils.readS(64, bytes)));
			case 0x43 | 0x44:
				throw "Float litterals are not implemented";
			// I32 CMP
			case 0x45:
				return Numeric(Generic(I32, Eqz));
			case 0x46:
				return Numeric(Generic(I32, Eq));
			case 0x47:
				return Numeric(Generic(I32, Ne));
			case 0x48:
				return Numeric(Generic(I32, Cmp(true, Lesser)));
			case 0x49:
				return Numeric(Generic(I32, Cmp(false, Lesser)));
			case 0x4a:
				return Numeric(Generic(I32, Cmp(true, Greater)));
			case 0x4b:
				return Numeric(Generic(I32, Cmp(false, Greater)));
			case 0x4c:
				return Numeric(Generic(I32, Cmp(true, LesserEqual)));
			case 0x4d:
				return Numeric(Generic(I32, Cmp(false, LesserEqual)));
			case 0x4e:
				return Numeric(Generic(I32, Cmp(true, GreaterEqual)));
			case 0x4f:
				return Numeric(Generic(I32, Cmp(false, GreaterEqual)));
			// I64 CMP
			case 0x50:
				return Numeric(Generic(I64, Eqz));
			case 0x51:
				return Numeric(Generic(I64, Eq));
			case 0x52:
				return Numeric(Generic(I64, Ne));
			case 0x53:
				return Numeric(Generic(I64, Cmp(true, Lesser)));
			case 0x54:
				return Numeric(Generic(I64, Cmp(false, Lesser)));
			case 0x55:
				return Numeric(Generic(I64, Cmp(true, Greater)));
			case 0x56:
				return Numeric(Generic(I64, Cmp(false, Greater)));
			case 0x57:
				return Numeric(Generic(I64, Cmp(true, LesserEqual)));
			case 0x58:
				return Numeric(Generic(I64, Cmp(false, LesserEqual)));
			case 0x59:
				return Numeric(Generic(I64, Cmp(true, GreaterEqual)));
			case 0x5a:
				return Numeric(Generic(I64, Cmp(false, GreaterEqual)));
			// F32 CMP
			case 0x5b:
				return Numeric(Generic(F32, Eq));
			case 0x5c:
				return Numeric(Generic(F32, Ne));
			case 0x5d:
				return Numeric(Generic(F32, Cmp(false, Lesser)));
			case 0x5e:
				return Numeric(Generic(F32, Cmp(false, Greater)));
			case 0x5f:
				return Numeric(Generic(F32, Cmp(false, LesserEqual)));
			case 0x60:
				return Numeric(Generic(F32, Cmp(false, GreaterEqual)));
			// F64 CMP
			case 0x61:
				return Numeric(Generic(F64, Eq));
			case 0x62:
				return Numeric(Generic(F64, Ne));
			case 0x63:
				return Numeric(Generic(F64, Cmp(false, Lesser)));
			case 0x64:
				return Numeric(Generic(F64, Cmp(false, Greater)));
			case 0x65:
				return Numeric(Generic(F64, Cmp(false, LesserEqual)));
			case 0x66:
				return Numeric(Generic(F64, Cmp(false, GreaterEqual)));

			// I32 Ops
			case 0x67:
				return Numeric(Integer(true, Clz));
			case 0x68:
				return Numeric(Integer(true, Ctz));
			case 0x69:
				return Numeric(Integer(true, PopCnt));
			case 0x6a:
				return Numeric(Generic(I32, Add));
			case 0x6b:
				return Numeric(Generic(I32, Sub));
			case 0x6c:
				return Numeric(Generic(I32, Mul));
			case 0x6d:
				return Numeric(Generic(I32, Div(true)));
			case 0x6e:
				return Numeric(Generic(I32, Div(false)));
			case 0x6f:
				return Numeric(Integer(true, Rem(true)));
			case 0x70:
				return Numeric(Integer(true, Rem(false)));
			case 0x71:
				return Numeric(Integer(true, And));
			case 0x72:
				return Numeric(Integer(true, Or));
			case 0x73:
				return Numeric(Integer(true, Xor));
			case 0x74:
				return Numeric(Integer(true, Shl));
			case 0x75:
				return Numeric(Integer(true, Shr(true)));
			case 0x76:
				return Numeric(Integer(true, Shr(false)));
			case 0x77:
				return Numeric(Integer(true, Rotl));
			case 0x78:
				return Numeric(Integer(true, Rotr));

			// I64 Ops
			case 0x79:
				return Numeric(Integer(false, Clz));
			case 0x7a:
				return Numeric(Integer(false, Ctz));
			case 0x7b:
				return Numeric(Integer(false, PopCnt));
			case 0x7c:
				return Numeric(Generic(I64, Add));
			case 0x7d:
				return Numeric(Generic(I64, Sub));
			case 0x7e:
				return Numeric(Generic(I64, Mul));
			case 0x7f:
				return Numeric(Generic(I64, Div(true)));
			case 0x80:
				return Numeric(Generic(I64, Div(false)));
			case 0x81:
				return Numeric(Integer(false, Rem(true)));
			case 0x82:
				return Numeric(Integer(false, Rem(false)));
			case 0x83:
				return Numeric(Integer(false, And));
			case 0x84:
				return Numeric(Integer(false, Or));
			case 0x85:
				return Numeric(Integer(false, Xor));
			case 0x86:
				return Numeric(Integer(false, Shl));
			case 0x87:
				return Numeric(Integer(false, Shr(true)));
			case 0x88:
				return Numeric(Integer(false, Shr(false)));
			case 0x89:
				return Numeric(Integer(false, Rotl));
			case 0x8a:
				return Numeric(Integer(false, Rotr));
			case x: throw 'Instruction is invalid or unimp: $x';
		}
	}
}

class BareExpr extends Expr {
	public function new(bytes: Iterator<Int>) {
		super(bytes);
		if (has_else) {
			throw "BareExpr ended in else";
		}
	}
}

class Expr {
	public var instrs(default, null): Array<Instr>;
	public var has_else(default, null): Bool;

	public function new(bytes: Iterator<Int>) {
		instrs = [];
		while(true) {
			var instr = InstrReader.readInstr(bytes);
			if (instr == BlockEnd) {
				has_else = false;
				break;
			} else if (instr == ElseEnd) {
				has_else = true;
				break;
			} else {
				instrs.push(instr);
			}
		}
	}

	public function prettyPrintIndent(indent: Int) {
		var indent_s = "";
		for (i in 0...indent) {
			indent_s += " ";
		}

		for (instr in instrs) {
			switch instr {
				case Block(b): switch b.instr {
					case Block(b):
						Sys.println(indent_s + "Block {");
						b.prettyPrintIndent(indent + 2);
						Sys.println(indent_s + "}");
					case Loop(b):
						Sys.println(indent_s + "Block {");
						b.prettyPrintIndent(indent + 2);
						Sys.println(indent_s + "}");
					case If(b,e):
						Sys.println(indent_s + "Block {");
						b.prettyPrintIndent(indent + 2);
						if (e != null) {
							Sys.println(indent_s + "} Else {");
							e.prettyPrintIndent(indent + 2);
						}
						Sys.println(indent_s + "}");
				};
				case _: Sys.println('$indent_s$instr');
			}
		}
	}

	public function toString(): String {
		return '{$instrs}';
	}
}

class Func {
	var locals: Array<Locals>;
	public var expr(default, null): Expr;

	public function new(bytes: Iterator<Int>) {
		locals = Utils.readVec(bytes, (b) -> new Locals(b));
		expr = new BareExpr(bytes);
	}

	public function locals_array(): Array<WasmValue> {
		return Lambda.flatMap(locals, (local) -> local.init());
	}

	public function toString(): String {
		return '($locals) => <...>';
	}
}

class Code {
	var size: Int;
	public var body(default, null): Func;

	public function new(bytes: Iterator<Int>) {
		size = Utils.readU(32, bytes);
		body = new Func(bytes);
	}

	public function toString(): String {
		return body.toString();
	}
}

enum FunctionKind {
	Import;
	Local;
}

class WasmBinary {
	static var MAGIC: Array<Int> = [0x00, 0x61, 0x73, 0x6d];
	static var VERSION: Array<Int> = [0x01, 0x00, 0x00, 0x00];
	var type: VecSection<FuncType>;
	var imports: VecSection<Import>;
	var functions: VecSection<Int>;
	var tables: VecSection<Table>;
	var memory: VecSection<MemType>;
	public var globals(default, null): VecSection<Globals>;
	var export: VecSection<Export>;
	public var code(default, null): VecSection<Code>;

	var maxImport: Int;
	var funcImports: Map<Int, Int>;

	public function resolve(func_id: Int): FunctionKind {
		if (func_id > maxImport) {
			return Local;
		} else {
			return Import;
		}
	}

	public function signature(func_id: Int): FuncType {
		var typeIdx = switch resolve(func_id) {
			case Local: functions.elements[func_id - (maxImport + 1)];
			case Import: funcImports[func_id];
		}
		return type.elements[typeIdx];
	}

	public function funcBody(func_id: Int): Func {
		var index = func_id - (maxImport + 1);
		return code.elements[index].body;
	}

	public function new(input: Iterable<Int>) {
		var input = input.iterator();

		var magic = [input.next(), input.next(), input.next(), input.next()];
		if (!Utils.equals(magic, WasmBinary.MAGIC)) {
			throw 'Invalid magic number: got ${magic} expected ${WasmBinary.MAGIC}';
		}

		var version = [input.next(), input.next(), input.next(), input.next()];
		if (!Utils.equals(version, WasmBinary.VERSION)) {
			throw 'Invalid version: got ${version} expected ${WasmBinary.VERSION}';
		}

		while(true) {
			var section_id = input.next();
			if (section_id == null) {
				break;
			}

			switch section_id {
				case 0: 
					// Dummy read the custom sections
					var section = new Section(input);
					section.dummyRead(input);
				case 1: 
					type = new VecSection(input, (b) -> new FuncType(b));
				case 2:
					imports = new VecSection(input, (b) -> new Import(b));
				case 3:
					functions = new VecSection(input, (b) -> Utils.readU(32, b));
				case 4:
					tables = new VecSection(input, (b) -> new Table(b));
				case 5:
					memory = new VecSection(input, (b) -> new MemType(b));
				case 6:
					globals = new VecSection(input, (b) -> new Globals(b));
				case 7:
					export = new VecSection(input, (b) -> new Export(b));
				case 8:
					var section = new Section(input);
					Sys.println("Start");
					section.dummyRead(input);
				case 9:
					var section = new Section(input);
					Sys.println("Element");
					section.dummyRead(input);
				case 10:
					code = new VecSection(input, (b) -> new Code(b));
				case 11:
					var section = new Section(input);
					Sys.println("Data");
					section.dummyRead(input);
			}
		}
		funcImports = [];
		maxImport = -1;
		for (i in 0...imports.elements.length) {
			var imp = imports.elements[i];
			switch imp.desc {
				case FuncRef(x): 
					maxImport += 1;
					funcImports[i] = x;
				case _:
			}
		}
	}

	public function find_export(symbol: String): ExportDesc {
		return Lambda.find(export.elements, (export) -> export.name == symbol).desc;
	}

	public function is_init_function(id: Int): Bool {
		var signature_id = functions.elements[id - 1];
		var signature = type.elements[signature_id];
		return signature.inputs.length == 0 && signature.outputs.length == 0;
	}

	public function info() {
		Sys.println("Types:");
		for(t in type.elements) {
			Sys.println("   " + t.toString());
		}
		Sys.println("Imports:");
		for(i in imports.elements) {
			Sys.println("   " + i.toString());
		}
		Sys.println('   Max funcref: $maxImport');
		Sys.println("Functions:");
		for(i in 0...functions.elements.length) {
			Sys.println('  f[${i + 1}] := ${functions.elements[i]}');
		}
		Sys.println("Tables:");
		for(t in tables.elements) {
			Sys.println("   " + t.toString());
		}
		Sys.println("Memory:");
		for(t in memory.elements) {
			Sys.println("   " + t.toString());
		}
		Sys.println("Globals:");
		for(g in globals.elements) {
			Sys.println("   " + g.toString());
		}
		Sys.println("Exports:");
		for(t in export.elements) {
			Sys.println("   " + t.toString());
		}
		Sys.println("Code:");
		for(t in code.elements) {
			Sys.println("   " + t.toString());
		}
	}
}

enum WasmValue {
	I32(v: Int);
	I64(v: Int);
	F32(v: Float);
	F64(v: Float);
}

class Frame {
	public var locals: Array<WasmValue>;
	public var code: Expr;
	public var iptr: Int;
	public var arity: Int;
	public var funcId: Int;

	public function new(l: Array<WasmValue>, c: Expr, a: Int, f: Int) {
		locals = l;
		code = c;
		iptr = 0;
		arity = a;
		funcId = f;
	}
}

class GlobalStore {
	public var globals: Array<WasmValue>;
	public var mut: Array<Mut>;

	public function new(binary: WasmBinary) {
		var count = binary.globals.elements.length;
		globals = [for (elem in binary.globals.elements) WasmInterpreter.constEval(elem.init)];
		mut = [for (elem in binary.globals.elements) elem.type.mut];
	}

	public function read(index: Int): WasmValue {
		return globals[index];
	}

	public function write(value: WasmValue, index: Int) {
		switch mut[index] {
			case Var: globals[index] = value;
			case Const: throw "Attempted to write to const global";
		}
	}
}

class WasmInterpreter {
	var binary: WasmBinary;
	var stack: Array<WasmValue>;
	var frames: Array<Frame>;
	var globals: GlobalStore;

	function current_frame(): Frame {
		return frames[frames.length - 1];
	}

	public function new(wasm: WasmBinary) {
		binary = wasm;
		stack = [];
		frames = [new Frame(null, null, 0, -1)];
		globals = new GlobalStore(wasm);
	}

	public static function constEval(expr: Expr): WasmValue {
		if (expr.instrs.length > 1) {
			throw "Only one instr in global";
		}
		if (expr.instrs.length == 0) {
			throw "No init was given";
		}
		switch expr.instrs[0] {
			case Numeric(I32(v)):
				return I32(v);
			case Numeric(I64(v)):
				return I64(v);
			case Numeric(F32(v)):
				return F32(v);
			case Numeric(F64(v)):
				return F64(v);
			case _: throw "Non const instruction in global init";
		}
	}

	public function execute_init(func_id: Int) {
		if (!binary.is_init_function(func_id)) {
			throw "Can't exec a function that is not () -> () as init";
		}

		call(func_id, [], 0);
		execute();
	}

	function call(func_id: Int, args: Array<WasmValue>, arity: Int) {
		switch binary.resolve(func_id) {
			case Local:
				Sys.println('Calling $func_id in ${current_frame().funcId}');
				var func = binary.funcBody(func_id);
				frames.push(new Frame(args.concat(func.locals_array()), func.expr, arity, func_id));
			case Import:
				throw "Can't execute imported functions yet";
		}
	}

	function execute() {
		while (true) {
			var frame = current_frame();
			if (frame.iptr > frame.code.instrs.length) {
				throw "IPTR overstepped code";
			}

			var instr = frame.code.instrs[frame.iptr];
			Sys.println("--> " + instr);
			switch instr {
				case Numeric(x): executeNumeric(frame, x);
				case Var(x): executeVar(frame, x);
				case Call(id): 
					executeCall(false, id);
					continue;
				case CallIndirect(id): 
					executeCall(true, id);
					continue;
				case Return: 
					executeReturn();
					continue;
				case x: throw '$x is not implemented';	
			}
			frame.iptr += 1;
		}
	}

	function executeReturn() {
		frames.pop();
		current_frame().iptr += 1;
	}

	function executeCall(indirect: Bool, id: Int) {
		if (indirect) {
			throw "Indirect call not implemented";
		}
		var signature = binary.signature(id);
		var arg_count = signature.inputs.length;
		var args = [for (i in 0...arg_count) stack.pop()];
		call(id, args, signature.outputs.length);
	}

	function executeVar(frame: Frame, instr: VarInstr) {
		if (instr.global) {
			switch instr.kind {
				case Tee:
					throw "Global Tee does not exist";
				case Set:
					globals.write(stack.pop(), instr.index);
				case Get:
					stack.push(globals.read(instr.index));
			}
		} else {
			switch instr.kind {
				case Set:
					frame.locals[instr.index] = stack.pop();
				case Get:
					stack.push(frame.locals[instr.index]);
				case Tee:
					frame.locals[instr.index] = stack[stack.length - 1];
			}
		}
	}

	function executeNumeric(frame: Frame, instr: Numeric) {
		switch instr {
			case I32(v): stack.push(I32(v));
			case I64(v): stack.push(I64(v));
			case F32(v): stack.push(F32(v));
			case F64(v): stack.push(F64(v));
			case Generic(type, operation): switch operation {
				case Sub | Add | Cmp(_) | Div(_) | Eq | Mul | Ne:
					var rhs = popAssertType(type);
					var lhs = popAssertType(type);
					switch type {
						case F32 | F64:
							switch operation {
								case Sub | Add | Mul | Div(_):
									var fn: (Float, Float) -> Float = switch operation {
										case Sub: (a,b) -> a-b;
										case Add: (a,b) -> a+b;
										case Mul: (a,b) -> a*b;
										case Div(signed): throw "Div not impl";
										case _: throw "Unreachable";
									}
									stack.push(Utils.floatBinOp(lhs, rhs, fn));
								case Cmp(_) | Eq | Ne:
									throw "Cmp | Eq | Ne not impl"; 
								case _:
							}
						case I32 | I64:
							switch operation {
								case Sub | Add | Mul | Div(_):
									var fn = switch operation {
										case Sub: (a,b) -> a-b;
										case Add: (a,b) -> a+b;
										case Mul: (a,b) -> a*b;
										case Div(signed): throw "Div not impl";
										case _: throw "Unreachable";
									}
									stack.push(Utils.intBinOp(lhs, rhs, fn));
								case Cmp(_) | Eq | Ne:
									throw "Cmp | Eq | Ne not impl"; 
								case _:
							}
					}
				case Eqz:
					throw "EQZ not impl";
			};
			case x: throw '$x is not implemented';
		}
	}

	function popAssertType(type: ValType): WasmValue {
		var value = stack.pop();
		switch value {
			case I32(_) if (type != I32): throw 'Invalid type: got $value expected $type';
			case I64(_) if (type != I64): throw 'Invalid type: got $value expected $type';
			case F32(_) if (type != F32): throw 'Invalid type: got $value expected $type';
			case F64(_) if (type != F64): throw 'Invalid type: got $value expected $type';
			case _: return value;
		}
	}
}
