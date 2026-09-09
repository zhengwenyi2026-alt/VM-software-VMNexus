import re

pbxproj = '/Users/wenyi/vm/AirVM.xcodeproj/project.pbxproj'
with open(pbxproj, 'r') as f:
    content = f.read()

# Map of filename -> fileRef ID
file_refs = {}
for match in re.finditer(r'^\t\t([A-F0-9]{24}) /\* ([^*]+\.h|[^*]+\.m) \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.(c\.h|c\.objc); path = \2; sourceTree = "<group>"; \};', content, re.MULTILINE):
    ref_id = match.group(1)
    filename = match.group(2)
    file_refs[filename] = ref_id

# Also handle AirVMExtensions.swift etc if needed, but we only care about engine files
engine_files = [
    'AirVMAppDelegate.h', 'AirVMAppDelegate.m',
    'AirVMQEMUProcess.h', 'AirVMQEMUProcess.m',
    'AirVMEngineProtocol.h',
    'AirVMEngineSelector.h', 'AirVMEngineSelector.m',
    'AirVMBasiliskProcess.h', 'AirVMBasiliskProcess.m',
    'AirVMMiniVMacProcess.h', 'AirVMMiniVMacProcess.m',
    'AirVMSheepShaverProcess.h', 'AirVMSheepShaverProcess.m',
    'AirVMDOSBoxProcess.h', 'AirVMDOSBoxProcess.m',
    'AirVMDOSBoxXProcess.h', 'AirVMDOSBoxXProcess.m',
    'AirVMPCemProcess.h', 'AirVMPCemProcess.m',
    'AirVM86BoxProcess.h', 'AirVM86BoxProcess.m',
    'AirVMVICEProcess.h', 'AirVMVICEProcess.m',
    'AirVMFSUAEProcess.h', 'AirVMFSUAEProcess.m',
    'AirVMHatariProcess.h', 'AirVMHatariProcess.m',
    'AirVMOpenMSXProcess.h', 'AirVMOpenMSXProcess.m',
    'AirVMFuseProcess.h', 'AirVMFuseProcess.m',
    'AirVMScummVMProcess.h', 'AirVMScummVMProcess.m',
    'AirVMMednafenProcess.h', 'AirVMMednafenProcess.m',
    'AirVMARAnyMProcess.h', 'AirVMARAnyMProcess.m',
]

children_lines = []
for fname in engine_files:
    if fname not in file_refs:
        print('MISSING:', fname)
        continue
    children_lines.append('\t\t\t\t%s /* %s */,' % (file_refs[fname], fname))

new_group = '\t\tA4FC1056D44D68CFE658FDD7 /* Engine */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n' + '\n'.join(children_lines) + '\n\t\t\t);\n\t\t\tpath = Engine;\n\t\t\tsourceTree = "<group>";\n\t\t};'

# Replace the entire Engine group block
pattern = r'\t\tA4FC1056D44D68CFE658FDD7 /\* Engine \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \([\s\S]*?\);\n\t\t\tpath = Engine;\n\t\t\tsourceTree = "<group>";\n\t\t\};'
content = re.sub(pattern, new_group, content)

with open(pbxproj, 'w') as f:
    f.write(content)

print('Engine group fixed')
