from pathlib import Path
import shutil
root = Path(__file__).resolve().parent.parent
res = root / 'android/app/src/main/res'
def write(path, text):
    p = res / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding='utf-8')
ns = 'xmlns:android="http://schemas.android.com/apk/res/android"'
write('layout/sometime_widget.xml', f'''<LinearLayout {ns} android:id="@+id/widget_root" android:layout_width="match_parent" android:layout_height="match_parent" android:orientation="vertical" android:padding="14dp" android:background="@drawable/widget_light">
<LinearLayout android:layout_width="match_parent" android:layout_height="30dp" android:gravity="center_vertical">
<TextView android:id="@+id/widget_brand" android:layout_width="0dp" android:layout_weight="1" android:layout_height="match_parent" android:gravity="center_vertical" android:text="Sometime" android:textSize="16sp" android:fontFamily="@font/geist" android:textStyle="bold"/>
<TextView android:id="@+id/widget_plus" android:layout_width="40dp" android:layout_height="match_parent" android:gravity="center" android:text="+" android:textSize="24sp"/>
</LinearLayout>
<LinearLayout android:id="@+id/widget_rows" android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical"/>
</LinearLayout>''')
write('layout/sometime_widget_heading.xml', f'''<TextView {ns} android:id="@+id/widget_heading" android:layout_width="match_parent" android:layout_height="26dp" android:gravity="center_vertical" android:textSize="10sp" android:fontFamily="@font/geist" android:textStyle="bold" android:maxLines="1" android:ellipsize="end"/>''')
write('layout/sometime_widget_task.xml', f'''<LinearLayout {ns} android:layout_width="match_parent" android:layout_height="32dp" android:gravity="center_vertical">
<TextView android:id="@+id/widget_complete" android:layout_width="30dp" android:layout_height="match_parent" android:gravity="center" android:text="○" android:textSize="20sp"/>
<TextView android:id="@+id/widget_title" android:layout_width="0dp" android:layout_weight="1" android:layout_height="match_parent" android:gravity="center_vertical" android:textSize="13sp" android:fontFamily="@font/geist" android:maxLines="1" android:ellipsize="end"/>
<TextView android:id="@+id/widget_time" android:layout_width="wrap_content" android:layout_height="match_parent" android:gravity="center_vertical" android:paddingStart="6dp" android:textSize="11sp" android:fontFamily="@font/geist"/>
</LinearLayout>''')
for mode, color in [('light', '#FAFAF8'), ('dark', '#121212')]:
    write(f'drawable/widget_{mode}.xml', f'<shape {ns}><solid android:color="{color}"/><corners android:radius="22dp"/></shape>')
for size, width, height, cells in [('small', 140, 180, 2), ('medium', 280, 250, 4)]:
    write(f'xml/sometime_widget_{size}.xml', f'''<appwidget-provider {ns} android:minWidth="{width}dp" android:minHeight="{height}dp" android:targetCellWidth="{cells}" android:targetCellHeight="3" android:updatePeriodMillis="0" android:initialLayout="@layout/sometime_widget" android:resizeMode="none" android:widgetCategory="home_screen" android:configure="de.eik.todo_app.SometimeWidgetConfiguration" android:widgetFeatures="reconfigurable"/>''')
(res / 'font').mkdir(exist_ok=True)
shutil.copyfile(root / 'assets/fonts/Geist-Variable.ttf', res / 'font/geist.ttf')
manifest = root / 'android/app/src/main/AndroidManifest.xml'
s = manifest.read_text()
entries = '<activity android:name=".SometimeWidgetConfiguration" android:exported="true" android:theme="@android:style/Theme.Material.Light.NoActionBar"><intent-filter><action android:name="android.appwidget.action.APPWIDGET_CONFIGURE"/></intent-filter></activity>\n'
for size in ['Small', 'Medium']:
    entries += f'''<receiver android:name=".{size}SometimeWidget" android:exported="false" android:label="Sometime {size}">
<intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE"/><action android:name="android.intent.action.BOOT_COMPLETED"/><action android:name="android.intent.action.TIME_SET"/><action android:name="android.intent.action.TIMEZONE_CHANGED"/><action android:name="android.intent.action.LOCALE_CHANGED"/></intent-filter>
<meta-data android:name="android.appwidget.provider" android:resource="@xml/sometime_widget_{size.lower()}"/></receiver>\n'''
s = s.replace('        <!-- Flutter uses', entries + '        <!-- Flutter uses')
manifest.write_text(s)
