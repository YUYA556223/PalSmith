# Creates WBP_SmithMenu (pure-visual list menu widget) + PrimaryAssetLabel in the
# PalworldModdingKit project, entirely from code - no editor GUI work.
#
# Design: the widget has NO blueprint graphs. All texts/visibility are driven at
# runtime from PalSmith's Lua via reflection (widgets marked bIsVariable become
# properties on the generated class). Input is keyboard-driven from Lua, so no
# buttons/click events are needed.
#
# Run headless:
#   UnrealEditor-Cmd.exe E:\PalworldModdingKit\Pal.uproject \
#     -run=pythonscript -script="E:\steam_hosts\pal\mods\PalSmith\tools\ue\make_smithmenu.py" \
#     -stdout -unattended -nosplash
import unreal

PKG = '/Game/Mods/PalSmithUI'
WIDGET = 'WBP_SmithMenu'
ROWS = 10

log = unreal.log
at = unreal.AssetToolsHelpers.get_asset_tools()
eal = unreal.EditorAssetLibrary


def set_prop(obj, names, value):
    """set_editor_property with fallback property names (API name drift guard)."""
    for n in names:
        try:
            obj.set_editor_property(n, value)
            return True
        except Exception:
            continue
    log('WARN: could not set any of %s on %s' % (names, obj.get_name()))
    return False


def make_widget_blueprint():
    path = f'{PKG}/{WIDGET}'
    if eal.does_asset_exist(path):
        eal.delete_asset(path)
        log('deleted existing ' + path)

    factory = unreal.WidgetBlueprintFactory()
    bp = at.create_asset(WIDGET, PKG, None, factory)
    assert bp, 'create_asset failed'

    # UWidgetBlueprint.WidgetTree is not script-exposed in 5.1; grab the
    # subobject directly by path instead.
    tree_path = bp.get_path_name() + ':WidgetTree'
    tree = unreal.find_object(None, tree_path) or unreal.load_object(None, tree_path)
    if not tree:
        tree = unreal.new_object(unreal.WidgetTree, outer=bp, name='WidgetTree')
    assert tree, 'could not resolve WidgetTree subobject'
    log('widget tree: ' + tree.get_path_name())

    def make(cls, name):
        return unreal.new_object(cls, outer=tree, name=name)

    # root canvas
    canvas = make(unreal.CanvasPanel, 'RootCanvas')
    tree.set_editor_property('root_widget', canvas)

    # centered dark panel
    border = make(unreal.Border, 'MenuBorder')
    slot = canvas.add_child(border)
    slot.set_anchors(unreal.Anchors(minimum=unreal.Vector2D(0.5, 0.5), maximum=unreal.Vector2D(0.5, 0.5)))
    slot.set_alignment(unreal.Vector2D(0.5, 0.5))
    slot.set_auto_size(True)
    set_prop(border, ['brush_color'], unreal.LinearColor(0.03, 0.03, 0.06, 0.92))
    border.set_padding(unreal.Margin(28.0, 20.0, 28.0, 20.0))

    vbox = make(unreal.VerticalBox, 'MenuBox')
    border.set_content(vbox)

    def add_text(name, default, size, color):
        t = make(unreal.TextBlock, name)
        set_prop(t, ['b_is_variable', 'is_variable'], True)
        t.set_text(unreal.Text(default))
        set_prop(t, ['color_and_opacity'],
                 unreal.SlateColor(unreal.LinearColor(*color)))
        try:
            font = t.get_editor_property('font')
            font.size = size
            t.set_editor_property('font', font)
        except Exception:
            log('WARN: font size not set for ' + name)
        s = vbox.add_child(t)
        try:
            s.set_padding(unreal.Margin(0.0, 2.0, 0.0, 2.0))
        except Exception:
            pass
        return t

    add_text('TitleText', 'PalSmith', 22, (1.0, 0.85, 0.4, 1.0))
    for i in range(ROWS):
        add_text('Row%d' % i, '', 16, (0.9, 0.9, 0.95, 1.0))
    add_text('FooterText', '', 12, (0.6, 0.65, 0.75, 1.0))

    unreal.BlueprintEditorLibrary.compile_blueprint(bp)
    eal.save_loaded_asset(bp)
    log('created + compiled ' + path)


def make_label():
    path = f'{PKG}/PalSmithUI_Label'
    if eal.does_asset_exist(path):
        log('label exists, skipping')
        return
    factory = unreal.DataAssetFactory()
    set_prop(factory, ['data_asset_class'], unreal.PrimaryAssetLabel)
    label = at.create_asset('PalSmithUI_Label', PKG, unreal.PrimaryAssetLabel, factory)
    assert label, 'label create failed'
    rules = label.get_editor_property('rules')
    rules.set_editor_property('chunk_id', 5100)
    rules.set_editor_property('cook_rule', unreal.PrimaryAssetCookRule.ALWAYS_COOK)
    label.set_editor_property('rules', rules)
    set_prop(label, ['label_assets_in_my_directory'], True)
    eal.save_loaded_asset(label)
    log('created label with chunk 5100')


make_widget_blueprint()
make_label()
log('=== make_smithmenu.py done ===')
