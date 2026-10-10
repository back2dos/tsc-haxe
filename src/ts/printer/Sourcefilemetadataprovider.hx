package ts.printer;

// Port of sourcefilemetadataprovider.go.

interface SourceFileMetaDataProvider {
	function GetSourceFileMetaData(path:Path):SourceFileMetaData;
}
