# Bulletproof introspection: write incrementally, guard everything.
import unreal, traceback
OUT = r'E:\steam_hosts\pal\mods\PalSmith\tools\ue\introspect_out.txt'
f = open(OUT, 'w')
def w(s):
    f.write(str(s) + '\n'); f.flush()

try:
    at = unreal.AssetToolsHelpers.get_asset_tools()
    bp = at.create_asset('WBP_Introspect', '/Game/Mods/PalSmithUI', None, unreal.WidgetBlueprintFactory())
    w('bp type: ' + type(bp).__name__)
    w('=== full dir(bp) ===')
    for a in dir(bp):
        if not a.startswith('__'):
            w('  ' + a)
    w('=== get_editor_property attempts ===')
    for name in ('WidgetTree', 'widget_tree', 'blueprint_widget_tree'):
        try:
            v = bp.get_editor_property(name)
            w('  OK "%s" -> %r' % (name, v))
        except Exception as e:
            w('  FAIL "%s" -> %s' % (name, e))
    w('=== unreal UMG type availability ===')
    for n in ('WidgetTree', 'UserWidget', 'CanvasPanel', 'VerticalBox', 'TextBlock',
              'Border', 'WidgetBlueprintLibrary', 'EditorUtilityLibrary'):
        w('  unreal.%s = %s' % (n, hasattr(unreal, n)))
except Exception:
    w('EXCEPTION:\n' + traceback.format_exc())
finally:
    f.close()
    unreal.log('introspect done')
