"""Called by test_and_render.py with its shared renderer."""
def run(c):
    g, paint, out = c['g'], c['paint'], c['OUT']
    count = 0
    for width, height in [(600, 800), (758, 1024), (1072, 1448), (800, 600)]:
        for large in (False, True):
            for dpi in (160, 300):
                g.D.dpi = dpi
                v = g.newView(25)
                v.state.animation = 'off'
                v.go(v, 'explore')
                if large:
                    g.E.act(v.state, 'preference', 'large_text', int(v.state.last))
                    g.E.act(v.state, 'preference', 'high_contrast', int(v.state.last))
                for name in ('town', 'meadow', 'centre', 'worldhelp', 'expeditions', 'battle', 'win', 'loss', 'save-error'):
                    w = v.state.world
                    w.battle = None
                    w.hp = 40
                    v.world_follow = None
                    v.world_save_failed = False
                    if name in ('town', 'meadow', 'centre'):
                        w.map, w.x, w.y = name, 6, 6
                        v.go(v, 'explore')
                    elif name in ('worldhelp', 'expeditions'):
                        v.go(v, name)
                    else:
                        w.map, w.x, w.y = 'meadow', 3, 3
                        assert g.E.world.startBattle(v.state, 1)
                        v.go(v, 'battle')
                        if name == 'win':
                            w.battle.hp = 1
                            g.E.world.turn(v.state, g.E, 1, int(v.state.last))
                        elif name == 'loss':
                            w.battle.turn, w.hp = 2, 1
                            g.E.world.turn(v.state, g.E, 2, int(v.state.last))
                        elif name == 'save-error':
                            v.world_save_failed = True
                    image = paint(v, width, height)
                    assert not c['truncated'], (name, width, large, dpi, c['truncated'])
                    for button in v.buttons.values():
                        assert button.x >= 0 and button.y >= 0
                        assert button.x + button.w <= 600 and button.y + button.h <= 800
                    if width == 600 and not large and dpi == 160:
                        image.save(out / f'world-{name}.png')
                    count += 1
                v.leave(v)
    g.D.dpi = None
    print(f'WORLD LAYOUTS: {count} map, battle, result and error screens fit sizes, DPI and larger text')
