extends PackedDataContainer

enum Compression {NONE, FASTLZ, DEFLATE, ZSTD, GZIP, BEST}

const CompressionMap := {
	Compression.NONE: -1,
	Compression.FASTLZ: File.COMPRESSION_FASTLZ,
	Compression.DEFLATE: File.COMPRESSION_DEFLATE,
	Compression.ZSTD: File.COMPRESSION_ZSTD,
	Compression.GZIP: File.COMPRESSION_GZIP
}

export var binary := false
export(Compression) var compression = Compression.NONE
export var original_size := 0

func set_data(filename: String) -> void:
	var input_file := File.new()
	var err: int = input_file.open(filename, _File.READ)
