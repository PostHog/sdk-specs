import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import ts from 'typescript';
import { createGenerator } from 'ts-json-schema-generator';

process.chdir(dirname(fileURLToPath(import.meta.url)));
const check = process.argv.includes('--check');
const read = path => readFileSync(path, 'utf8');
const digest = text => createHash('sha256').update(text).digest('hex');
const provenance = JSON.parse(read('inputs/provenance.json'));
for (const input of [provenance.catalog, provenance.decisions, ...provenance.amendments]) {
  assert.equal(digest(read(`inputs/${input.path}`)), input.sha256, `Changed frozen input ${input.path}`);
}
const amendments = provenance.amendments.map(({ id, path, sha256 }) => ({ id, path: `inputs/${path}`, sha256 }));
// UTF-8, LF-delimited, final LF; order is the provenance amendment order.
const effectiveHash = digest([provenance.catalog.sha256, ...amendments.map(a => `${a.id}:${a.sha256}`)].join('\n') + '\n');
const text = read(`inputs/${provenance.catalog.path}`);
const blocks = [...text.matchAll(/```typescript\n([\s\S]*?)```/g)];
const interfaces = new Map();
for (const block of blocks) {
  const file = ts.createSourceFile('catalog.ts', block[1], ts.ScriptTarget.Latest, true);
  const startLine = text.slice(0, block.index + '```typescript\n'.length).split('\n').length;
  for (const node of file.statements) {
    if (ts.isInterfaceDeclaration(node) && !node.typeParameters) interfaces.set(node.name.text, { node, file, startLine });
  }
}
const configurations = [];
function expand(name, prefix) {
  const { node, file, startLine } = interfaces.get(name);
  for (const member of node.members) {
    assert(ts.isPropertySignature(member));
    const path = `${prefix}.${member.name.getText(file)}`;
    configurations.push({ path, type: member.type.getText(file), catalog_line: startLine + file.getLineAndCharacterOfPosition(member.getStart(file)).line });
    function visit(type) {
      if (ts.isTypeReferenceNode(type) && interfaces.has(type.typeName.getText(file))) expand(type.typeName.getText(file), path);
      else ts.forEachChild(type, visit);
    }
    visit(member.type);
  }
}
expand('SetupConfig', 'config');
const clean = value => value.trim().replaceAll('`', '').replaceAll('&#124;', '|');
const operations = text.split('\n').flatMap((line, index) => {
  if (!/^\| `\/[^`]+` \|/.test(line)) return [];
  const [route, args, result, behavior] = line.slice(1, -1).split('|').map(clean);
  const name = 'Op' + route.slice(1).split(/[_/]/).map(part => part[0].toUpperCase() + part.slice(1)).join('');
  return [{ route, name, args, result, receiver_kind: /\*\*(\w+)\*\*/.exec(behavior)?.[1] ?? 'instance', behavior, catalog_line: index + 1 }];
});
assert.equal(operations.length, 180);
assert.equal(new Set(operations.map(op => op.route)).size, 180);
assert.equal(configurations.length, 143);
assert.equal(new Set(configurations.map(c => c.path)).size, 143);
// Cross-check phase-1 when present; generation remains standalone when distributed.
try {
  const inventory = read('../../coverage/harness-v2/catalog-config.jsonl').trim().split('\n').map(JSON.parse);
  assert.deepEqual(configurations, inventory.map(({ path, type, catalog_line }) => ({ path, type, catalog_line })));
  const routes = read('../../coverage/harness-v2/catalog-routes.jsonl').trim().split('\n').map(JSON.parse);
  assert.deepEqual(operations.map(op => [op.route, op.args, op.result, op.catalog_line]), routes.map(op => [op.route, clean(op.arguments), clean(op.result), op.catalog_line]));
} catch (error) { if (error.code !== 'ENOENT') throw error; }
// Phase-1 cross-checks above deliberately describe the frozen base, not the overlay.
configurations.push({ path: 'config.disable_geoip', type: 'boolean', amendment: 'capture-amendment-v1', source: 'inputs/capture-amendment-v1.ts#L5' });
const capture = operations.find(op => op.route === '/capture');
capture.args = 'CaptureArgs';
capture.amendment = 'capture-amendment-v1';
operations.find(op => op.route === '/setup').amendment = 'capture-amendment-v1';
const flagListener = operations.find(op => op.route === '/on_feature_flags');
flagListener.behavior = 'Native enabled flag keys, values/variants and optional loading context; immediate when loaded and on subsequent notifications, including errors. Actual subscription removal.';
flagListener.amendment = 'flag-semantics-v1';
const reload = operations.find(op => op.route === '/reload_feature_flags');
reload.behavior += ' For declared native local evaluation, invokes public definitions refresh; void alone is not fresh-load readiness.';
reload.amendment = 'local-evaluation-v1';
let source = blocks.map(block => block[1]).join('\n');
// The frozen catalog's transport sketch is superseded by protocol.ts, not a second wire API.
source = source.replace(/interface Invoke \{[\s\S]*?\n\}/, '').replace(/type Outcome = [\s\S]*?error: ErrorRef \};/, '');
source = source.replace(/^((?:type|interface) \w+)/gm, 'export $1');
// JSON object keys are strings; the catalog's question indexes are zero-based integers.
source = source.replace('Record<integer, SurveyResponse>', 'Record<QuestionIndex, SurveyResponse>');
source += '\n/** @pattern ^(0|[1-9][0-9]*)$ */\nexport type QuestionIndex = string;\n';
source = source.replace('export type integer = number;', '/** @asType integer */\nexport type integer = number;');
source = source.replace('export type Timestamp = string;', '/** @pattern ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]{1,9})?(Z|[+-][0-9]{2}:[0-9]{2})$ */\nexport type Timestamp = string;');
source = source.replace('export interface SetupConfig {', 'export interface BaseSetupConfig {')
  .replace('Omit<SetupConfig,', 'Omit<BaseSetupConfig,');
source += '\n' + amendments.map(a => read(a.path)).join('\n');
source += `\nexport type CatalogHash = ${JSON.stringify(effectiveHash)};\n`;
for (const op of operations) {
  const args = op.args === 'none' ? 'Record<string, never>' : op.args.includes(':') ? `{ ${op.args} }` : op.args;
  source += `\nexport type ${op.name}Args = ${args};\n`;
  source += `export type ${op.name}Result = ${op.result === 'void' ? '{ kind: "void" }' : `{ kind: "value"; value: ${op.result} }`};\n`;
}
source += `\nexport type OperationRoute = ${operations.map(op => JSON.stringify(op.route)).join(' | ')};\n`;
source = `// Generated from inputs/public-rpc-catalog.md (${provenance.catalog.sha256}).\n// Effective catalog ${effectiveHash}; amendments: ${amendments.map(a => a.id + ":" + a.sha256).join(", ")}.
// Do not edit; npm run generate. Type schemas are semantic targets, not Invoke admission gates.\n${source}`;
const temp = mkdtempSync(join(tmpdir(), 'sdk-contracts-v2-'));
function emit(path, value) {
  const contents = typeof value === 'string' ? value : JSON.stringify(value, null, 2) + '\n';
  if (check) assert.equal(read(path), contents, `Stale generated artifact: ${path}`);
  else writeFileSync(path, contents);
}
try {
  writeFileSync(join(temp, 'catalog.ts'), source);
  writeFileSync(join(temp, 'protocol.ts'), read('protocol.ts').replaceAll('./generated/catalog.js', './catalog.js'));
  writeFileSync(join(temp, 'tsconfig.json'), JSON.stringify({ compilerOptions: { strict: true, target: 'ES2022', module: 'NodeNext', moduleResolution: 'NodeNext', skipLibCheck: true } }));
  const schema = name => createGenerator({ path: join(temp, `${name}.ts`), tsconfig: join(temp, 'tsconfig.json'), type: '*', expose: 'export', topRef: true, additionalProperties: false, jsDoc: 'extended', skipTypeCheck: false }).createSchema('*');
  const catalog = schema('catalog');
  const protocol = schema('protocol');
  catalog.$id = 'https://posthog.com/sdk-contracts/2.0.0/catalog.schema.json';
  protocol.$id = 'https://posthog.com/sdk-contracts/2.0.0/protocol.schema.json';
  for (const op of operations) {
    assert(catalog.definitions[`${op.name}Args`]);
    assert(catalog.definitions[`${op.name}Result`]);
  }
  function resultReferenceKinds(schema) {
    if (schema.$ref) return resultReferenceKinds(catalog.definitions[decodeURIComponent(schema.$ref.split('/').at(-1))]);
    if (schema.anyOf) return schema.anyOf.flatMap(resultReferenceKinds);
    return schema.properties?.kind?.const && schema.properties?.id ? [schema.properties.kind.const] : [];
  }
  const policy = { catalog_sha256: effectiveHash, base_catalog_sha256: provenance.catalog.sha256, amendments, defaults: 'inputs/public-rpc-catalog.md#4-defaults-and-completion', behavior: 'inputs/public-rpc-catalog.md#5-shared-behavior', decisions: 'inputs/public-rpc-decisions.md', policy_overrides: ['inputs/flag-semantics-v1.ts', 'inputs/local-evaluation-v1.ts'] };
  emit('generated/catalog.ts', source);
  emit('generated/catalog.schema.json', catalog);
  emit('generated/protocol.schema.json', protocol);
  emit('generated/operations.json', { contract_version: '2.0.0', ...policy, operations: operations.map(({ name, args, result, ...op }) => ({ ...op, arguments_schema: `catalog.schema.json#/definitions/${name}Args`, result_schema: `catalog.schema.json#/definitions/${name}Result`, result_kind: result === 'void' ? 'void' : 'value', result_type: result, result_reference_kinds: result === 'void' ? [] : resultReferenceKinds(catalog.definitions[`${name}Result`].properties.value), source: `inputs/public-rpc-catalog.md#L${op.catalog_line}` })) });
  emit('generated/configuration.json', { contract_version: '2.0.0', ...policy, schema: 'catalog.schema.json#/definitions/SetupConfig', paths: configurations });
  console.log(`${check ? 'Checked' : 'Generated'} 180 typed operations / 144 configuration paths; catalog + protocol JSON Schema draft-07`);
} finally { rmSync(temp, { recursive: true, force: true }); }
