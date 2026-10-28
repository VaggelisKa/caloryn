# CloudKit schema

TestFlight and App Store builds sync against CloudKit **Production**, which never adds a
field on its own. It rejects any record carrying a field it does not know, and one
rejected record fails its whole upload batch, so the device silently stops uploading.
Debug builds talk to **Development**, which does add fields as records are written, but
only fields that hold a value. A nil optional never reaches the schema.

Three files in `CalorynTests/CloudKit/` keep this honest:

- `ModelSchema.ckdb` is the schema the models need, rendered by `CloudKitSchemaFile`.
  `testModelSchemaFileMatchesTheModels` fails after any `@Model` change until it is
  re-recorded (delete it, run the test twice).
- `ProductionSchema.ckdb` is the last export of Production.
  `testProductionAcceptsEveryFieldTheModelsCanWrite` fails until Production has every
  field in the model schema.
- `testTheModelSchemaTypesEveryFieldAsProductionAlreadyStoresIt` checks the rendered
  types against fields Production already holds, which is the evidence for the
  attribute-to-CloudKit type mapping.

## After changing a model

1. Re-record `ModelSchema.ckdb` and review its diff.
2. Create a management token in the [CloudKit Console](https://icloud.developer.apple.com)
   and save it once; `cktool` prompts for it and keeps it in the keychain.

   ```bash
   xcrun cktool save-token --type management
   ```

3. Import the model schema into Development:

   ```bash
   xcrun cktool import-schema --team-id BN8VYT9W96 --container-id iCloud.www.caloryn --environment development --validate --file CalorynTests/CloudKit/ModelSchema.ckdb
   ```

4. In the console, open `iCloud.www.caloryn` → Development → **Deploy Schema Changes**,
   check the diff, and deploy. Production fields can never be removed afterwards.
5. Export Production over the checked-in copy and commit it with the model change:

   ```bash
   xcrun cktool export-schema --team-id BN8VYT9W96 --container-id iCloud.www.caloryn --environment production --output-file CalorynTests/CloudKit/ProductionSchema.ckdb
   ```

Devices that were failing upload their backlog on their next launch once Production
accepts the fields.

## Without a token

A signed Debug build launched with `-initialize-cloudkit-schema` asks Core Data to write
the schema to Development itself (`CloudKitSchemaInitializer`). It needs a simulator or
spare device signed into iCloud, never one with data you care about, since a Debug
build points the app's store at Development. Simulator builds are ad-hoc signed with
the entitlements unless `CODE_SIGNING_ALLOWED=NO` is passed. Watch the result with
`log stream --predicate 'subsystem == "www.caloryn" AND category == "CloudKitSchema"'`,
then continue from step 4.
