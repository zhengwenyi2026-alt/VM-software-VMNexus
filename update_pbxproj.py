import re
import uuid
import os

pbxproj = '/Users/wenyi/vm/AirVM.xcodeproj/project.pbxproj'
with open(pbxproj, 'r') as f:
    content = f.read()

new_files = [
    'AirVMSheepShaverProcess',
    'AirVMDOSBoxProcess',
    'AirVMDOSBoxXProcess',
    'AirVMPCemProcess',
    'AirVM86BoxProcess',
    'AirVMVICEProcess',
    'AirVMFSUAEProcess',
    'AirVMHatariProcess',
    'AirVMOpenMSXProcess',
    'AirVMFuseProcess',
    'AirVMScummVMProcess',
    'AirVMMednafenProcess',
    'AirVMARAnyMProcess',
]

def gen_id():
    return uuid.uuid4().hex.upper()[:24]

ids = {}
for name in new_files:
    ids[name] = {'h': gen_id(), 'm': gen_id(), 'build': gen_id()}

# 1. PBXBuildFile section: find end and insert
build_files = []
for name in new_files:
    build_files.append('\t\t{build} /* {name}.m in Sources */ = {{isa = PBXBuildFile; fileRef = {m} /* {name}.m */; }};'.format(
        build=ids[name]['build'], name=name, m=ids[name]['m']))

build_end_marker = '/* End PBXBuildFile section */'
content = content.replace(build_end_marker, '\n'.join(build_files) + '\n' + build_end_marker)

# 2. PBXFileReference section: find end and insert
file_refs = []
for name in new_files:
    file_refs.append('\t\t{h} /* {name}.h */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = {name}.h; sourceTree = "<group>"; }};'.format(
        h=ids[name]['h'], name=name))
    file_refs.append('\t\t{m} /* {name}.m */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = {name}.m; sourceTree = "<group>"; }};'.format(
        m=ids[name]['m'], name=name))

file_ref_end = '/* End PBXFileReference section */'
content = content.replace(file_ref_end, '\n'.join(file_refs) + '\n' + file_ref_end)

# 3. Engine group children: insert before closing of Engine group
engine_group_close = '\t\t\tAA001111222233340007 /* AirVMMiniVMacProcess.m */,\n\t\t);\n\t\tpath = Engine;'
new_children = '\t\t\tAA001111222233340007 /* AirVMMiniVMacProcess.m */,\n'
for name in new_files:
    new_children += '\t\t\t{h} /* {name}.h */,\n'.format(h=ids[name]['h'], name=name)
    new_children += '\t\t\t{m} /* {name}.m */,\n'.format(m=ids[name]['m'], name=name)
new_children += '\t\t);\n\t\tpath = Engine;'
content = content.replace(engine_group_close, new_children)

# 4. Sources build phase: insert before AirVMVirtualMachine.m
sources_marker = '\t\t\tAA001111222233340017 /* AirVMMiniVMacProcess.m in Sources */,\n'
new_sources = sources_marker
for name in new_files:
    new_sources += '\t\t\t{build} /* {name}.m in Sources */,\n'.format(build=ids[name]['build'], name=name)
content = content.replace(sources_marker, new_sources)

with open(pbxproj, 'w') as f:
    f.write(content)

print('Added %d new engine files to project.pbxproj' % len(new_files))
