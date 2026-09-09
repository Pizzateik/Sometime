from pathlib import Path
import plistlib
root = Path(__file__).resolve().parent.parent
ios = root / 'ios'
group = {'com.apple.security.application-groups': ['group.de.eik.todoApp']}
for entitlement_path in ['Runner/Runner.entitlements', 'SometimeWidget/SometimeWidget.entitlements']:
    (ios / entitlement_path).write_bytes(plistlib.dumps(group))
widget_info = {'CFBundleDisplayName': 'Sometime', 'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)', 'CFBundleExecutable': '$(EXECUTABLE_NAME)', 'CFBundleName': '$(PRODUCT_NAME)', 'CFBundlePackageType': 'XPC!', 'CFBundleShortVersionString': '1.0.0', 'CFBundleVersion': '1', 'NSExtension': {'NSExtensionPointIdentifier': 'com.apple.widgetkit-extension'}, 'UIAppFonts': ['Geist-Variable.ttf']}
(ios / 'SometimeWidget/Info.plist').write_bytes(plistlib.dumps(widget_info))
runner_info_path = ios / 'Runner/Info.plist'
runner_info = plistlib.loads(runner_info_path.read_bytes())
runner_info['CFBundleURLTypes'] = [{'CFBundleURLSchemes': ['sometime'], 'CFBundleURLName': 'de.eik.todoApp.widgets'}]
runner_info['CFBundleLocalizations'] = ['de', 'en']
runner_info_path.write_bytes(plistlib.dumps(runner_info))

project_path = ios / 'Runner.xcodeproj/project.pbxproj'
project = project_path.read_text()
def add(section, content):
    global project
    project = project.replace(f'/* End {section} section */', content + f'\n/* End {section} section */')
def oid(number): return f'A5700000000000000000{number:04X}'
add('PBXFileReference', f'''
{oid(1)} = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SometimeWidget/SometimeWidget.swift; sourceTree = SOURCE_ROOT; }};
{oid(2)} = {{isa = PBXFileReference; explicitFileType = wrapper.app-extension; path = SometimeWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
{oid(3)} = {{isa = PBXFileReference; lastKnownFileType = file; path = "../assets/fonts/Geist-Variable.ttf"; sourceTree = SOURCE_ROOT; }};
{oid(4)} = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; path = SometimeWidget/de.lproj/Localizable.strings; sourceTree = SOURCE_ROOT; }};
{oid(5)} = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; path = SometimeWidget/en.lproj/Localizable.strings; sourceTree = SOURCE_ROOT; }};
''')
add('PBXVariantGroup', f'{oid(6)} = {{isa = PBXVariantGroup; children = ({oid(4)}, {oid(5)}); name = Localizable.strings; sourceTree = "<group>"; }};')
# Localized variant children need their language names.
project = project.replace('path = SometimeWidget/de.lproj', 'name = de; path = SometimeWidget/de.lproj').replace('path = SometimeWidget/en.lproj', 'name = en; path = SometimeWidget/en.lproj')
add('PBXBuildFile', '\n'.join(f'{oid(n+10)} = {{isa = PBXBuildFile; fileRef = {oid(n)}; }};' for n in [1, 3, 6]) + f'\n{oid(12)} = {{isa = PBXBuildFile; fileRef = {oid(2)}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};')
add('PBXSourcesBuildPhase', f'{oid(21)} = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({oid(11)}, ); runOnlyForDeploymentPostprocessing = 0; }};')
add('PBXResourcesBuildPhase', f'{oid(22)} = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({oid(13)}, {oid(16)}, ); runOnlyForDeploymentPostprocessing = 0; }};')
add('PBXFrameworksBuildPhase', f'{oid(23)} = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};')
add('PBXCopyFilesBuildPhase', f'{oid(24)} = {{isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = ({oid(12)}, ); name = "Embed App Extensions"; runOnlyForDeploymentPostprocessing = 0; }};')
add('PBXContainerItemProxy', f'{oid(25)} = {{isa = PBXContainerItemProxy; containerPortal = 97C146E61CF9000F007C117D; proxyType = 1; remoteGlobalIDString = {oid(30)}; remoteInfo = SometimeWidget; }};')
add('PBXTargetDependency', f'{oid(26)} = {{isa = PBXTargetDependency; target = {oid(30)}; targetProxy = {oid(25)}; }};')
add('PBXNativeTarget', f'{oid(30)} = {{isa = PBXNativeTarget; buildConfigurationList = {oid(40)}; buildPhases = ({oid(21)}, {oid(23)}, {oid(22)}, ); buildRules = (); dependencies = (); name = SometimeWidget; productName = SometimeWidget; productReference = {oid(2)}; productType = "com.apple.product-type.app-extension"; }};')
for n, name in [(41, 'Debug'), (42, 'Release'), (43, 'Profile')]:
    add('XCBuildConfiguration', f'{oid(n)} = {{isa = XCBuildConfiguration; buildSettings = {{APPLICATION_EXTENSION_API_ONLY = YES; CODE_SIGN_ENTITLEMENTS = SometimeWidget/SometimeWidget.entitlements; CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = SometimeWidget/Info.plist; IPHONEOS_DEPLOYMENT_TARGET = 17.0; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"; PRODUCT_BUNDLE_IDENTIFIER = de.eik.todoApp.SometimeWidget; PRODUCT_NAME = "$(TARGET_NAME)"; SDKROOT = iphoneos; SKIP_INSTALL = YES; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = "1,2"; }}; name = {name}; }};')
add('XCConfigurationList', f'{oid(40)} = {{isa = XCConfigurationList; buildConfigurations = ({oid(41)}, {oid(42)}, {oid(43)}, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};')
project = project.replace('97C146EE1CF9000F007C117D /* Runner.app */,', f'97C146EE1CF9000F007C117D /* Runner.app */,\n{oid(2)},')
project = project.replace('97C146F01CF9000F007C117D /* Runner */,', f'97C146F01CF9000F007C117D /* Runner */,\n{oid(1)}, {oid(3)}, {oid(6)},')
project = project.replace('3B06AD1E1E4923F5004D2608 /* Thin Binary */,', f'{oid(24)},\n3B06AD1E1E4923F5004D2608 /* Thin Binary */,')
project = project.replace('dependencies = (\n\t\t\t);\n\t\t\tname = Runner;', f'dependencies = ({oid(26)}, );\n\t\t\tname = Runner;')
project = project.replace('targets = (', f'targets = (\n{oid(30)},')
project = project.replace('PRODUCT_BUNDLE_IDENTIFIER = de.eik.todoApp;', 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\nPRODUCT_BUNDLE_IDENTIFIER = de.eik.todoApp;')
project_path.write_text(project)
english = ['Space', 'Category', 'Today', 'Soon', 'Sometime', 'All', 'Sometime widget', 'Choose a space and a category.', 'Your tasks, on this device.']
german = ['Space', 'Kategorie', 'Heute', 'Demnächst', 'Irgendwann', 'Alle', 'Sometime-Widget', 'Wähle einen Space und eine Kategorie.', 'Deine Aufgaben auf diesem Gerät.']
for locale, values in [('en', english), ('de', german)]:
    folder = ios / f'SometimeWidget/{locale}.lproj'
    folder.mkdir(exist_ok=True)
    (folder / 'Localizable.strings').write_text('\n'.join(f'"{key}" = "{value}";' for key, value in zip(english, values)), encoding='utf-8')
