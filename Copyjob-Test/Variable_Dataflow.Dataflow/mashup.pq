[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared WorkspaceId = let
  WorkspaceId = Variable.ValueOrDefault("$(/**/dataflow-variables/WorkspaceId)", "559fe1ea-bf64-46ef-a593-39be8c7e36f4")
  in
  WorkspaceId;
shared LakehouseId = let
LakehouseId =
  Variable.ValueOrDefault("$(/**/dataflow-variables/LakehouseId)",
  "1317f12b-3d45-4cbf-bce7-cb60751e725c")
  in
  LakehouseId;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "holidaydatacontainer_DataDestination", IsNewTarget = true], Settings = [Kind = "Manual", AllowCreation = true, ColumnSettings = [Mappings = {[SourceColumnName = "countryOrRegion", DestinationColumnName = "countryOrRegion"], [SourceColumnName = "holidayName", DestinationColumnName = "holidayName"], [SourceColumnName = "normalizeHolidayName", DestinationColumnName = "normalizeHolidayName"], [SourceColumnName = "isPaidTimeOff", DestinationColumnName = "isPaidTimeOff"], [SourceColumnName = "countryRegionCode", DestinationColumnName = "countryRegionCode"], [SourceColumnName = "date", DestinationColumnName = "date"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared holidaydatacontainer = let
    // 1) Read variables INLINE (recommended by Microsoft Learn examples)
    WorkspaceIdRaw = Variable.ValueOrDefault("$(/**/dataflow-variables/WorkspaceId)", "559fe1ea-bf64-46ef-a593-39be8c7e36f4"),
    LakehouseIdRaw = Variable.ValueOrDefault("$(/**/dataflow-variables/LakehouseId)", "1317f12b-3d45-4cbf-bce7-cb60751e725c"),
    RegionRaw      = Variable.ValueOrDefault("$(/**/dataflow-variables/Region)",      "Sweden"),

    // 2) Normalize any shape -> text (handles: text, 1-cell table, list, record)
    ToText = (v as any) as nullable text =>
        if Value.Is(v, type text) then v
        else if Value.Is(v, type table) then
            let t = v in
                if Table.RowCount(t)=0 then null
                else
                    // common Dataflow variable shape: #table({"Value"}, {{...}})
                    if List.Contains(Table.ColumnNames(t), "Value") then try Text.From(t{0}[Value]) otherwise null
                    else try Text.From(Record.FieldValues(t{0}){0}) otherwise null
        else if Value.Is(v, type list) then try Text.From(v{0}) otherwise null
        else if Value.Is(v, type record) then try Text.From(Record.FieldValues(v){0}) otherwise null
        else try Text.From(v) otherwise null,

    WorkspaceId = ToText(WorkspaceIdRaw),
    LakehouseId = ToText(LakehouseIdRaw),
    Region      = ToText(RegionRaw),

    // 3) Fail fast with clear messages (instead of key-not-found)
    _checkWorkspaceId = if WorkspaceId = null or Text.Length(Text.Trim(WorkspaceId))=0
        then error "WorkspaceId resolved to blank/empty. Check variable library name/path and refresh identity permissions."
        else null,

    _checkLakehouseId = if LakehouseId = null or Text.Length(Text.Trim(LakehouseId))=0
        then error "LakehouseId resolved to blank/empty. Check variable library name/path."
        else null,

    // 4) Use the documented Lakehouse connector pattern (Learn examples use [] rather than null)
    Source = Lakehouse.Contents([]),

    _checkSource = if Table.RowCount(Source)=0
        then error "Lakehouse.Contents returned 0 workspaces. Refresh identity likely cannot see any workspaces (credentials/permissions)."
        else null,

    Navigation      = Source{[workspaceId = WorkspaceId]}[Data],
    Navigation1     = Navigation{[lakehouseId = LakehouseId]}[Data],
    HolidayTable    = Navigation1{[Id = "holidaydatacontainer", ItemKind = "Table"]}[Data],
    FilteredRows    = Table.SelectRows(HolidayTable, each [countryOrRegion] = Region)
in
    FilteredRows;
shared Region = let
  Source = Variable.ValueOrDefault("$(/**/dataflow-variables/Region)", "Sweden")
  in
  Source;
shared holidaydatacontainer_DataDestination = let
  Pattern = Fabric.Warehouse([HierarchicalNavigation = null, CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "559fe1ea-bf64-46ef-a593-39be8c7e36f4"]}[Data],
  Navigation_2 = Navigation_1{[warehouseId = "2be1a691-4c67-4b88-b1e7-e67f5948ee91"]}[Data],
  TableNavigation = Navigation_2{[Item = "holidaydatacontainer", Schema = "dbo"]}?[Data]?
in
  TableNavigation;
