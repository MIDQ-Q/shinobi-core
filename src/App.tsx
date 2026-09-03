import { NodeGraph } from './components/NodeGraph';
import { VoxelPreview } from './components/VoxelPreview';
import { useGraphStore } from './stores/graphStore';
import { Save, Download, Settings, Box } from 'lucide-react';

function App() {
  const name = useGraphStore((state) => state.nodes[0]?.data?.label || 'Новая техника');

  return (
    <div className="flex flex-col h-screen w-screen bg-background text-foreground">
      {/* HEADER */}
      <header className="h-14 border-b border-border bg-card/50 backdrop-blur flex items-center justify-between px-4 shrink-0">
        <div className="flex items-center gap-2">
          <Box className="w-5 h-5 text-primary" />
          <h1 className="font-bold text-lg tracking-tight">Shinobi <span className="text-primary">Editor</span></h1>
          <span className="text-xs text-muted-foreground ml-2 px-2 py-0.5 bg-secondary rounded-full">v3.0 Alpha</span>
        </div>
        <div className="flex items-center gap-2">
          <span className="text-sm text-muted-foreground mr-2">Редактирование: <span className="text-foreground font-medium">{name}</span></span>
          <button className="p-2 hover:bg-accent rounded-md transition-colors" title="Настройки">
            <Settings className="w-4 h-4" />
          </button>
          <button className="flex items-center gap-2 bg-primary hover:bg-primary/90 text-primary-foreground px-3 py-1.5 rounded-md text-sm font-medium transition-colors">
            <Save className="w-4 h-4" /> Сохранить
          </button>
          <button className="flex items-center gap-2 bg-secondary hover:bg-secondary/80 text-secondary-foreground px-3 py-1.5 rounded-md text-sm font-medium transition-colors border border-border">
            <Download className="w-4 h-4" /> Экспорт JSON
          </button>
        </div>
      </header>

      {/* MAIN CONTENT */}
      <main className="flex-1 flex overflow-hidden">
        {/* LEFT SIDEBAR: Palette */}
        <aside className="w-64 border-r border-border bg-card/30 flex flex-col shrink-0">
          <div className="p-3 border-b border-border">
            <h2 className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">Библиотека фаз</h2>
          </div>
          <div className="flex-1 overflow-y-auto p-3 space-y-4">
            {['Триггеры', 'Доставка', 'Контакт', 'Область', 'Статус', 'Завершение', 'Модификаторы'].map((category) => (
              <div key={category}>
                <h3 className="text-xs font-medium text-zinc-400 mb-2">{category}</h3>
                <div className="space-y-1">
                  {['Элемент 1', 'Элемент 2', 'Элемент 3'].map((item, i) => (
                    <div 
                      key={i} 
                      className="p-2 bg-secondary/50 hover:bg-secondary border border-transparent hover:border-border rounded text-xs cursor-grab active:cursor-grabbing transition-all"
                      draggable
                      onDragStart={(e) => e.dataTransfer.setData('application/reactflow', `${category}-${item}`)}
                    >
                      {item}
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </aside>

        {/* CENTER: Node Graph */}
        <section className="flex-1 flex flex-col min-w-0 bg-zinc-950/50">
          <div className="flex-1 p-4 min-h-0">
            <NodeGraph />
          </div>
        </section>

        {/* RIGHT SIDEBAR: Properties & Preview */}
        <aside className="w-80 border-l border-border bg-card/30 flex flex-col shrink-0">
          <div className="p-3 border-b border-border">
            <h2 className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">Свойства узла</h2>
          </div>
          <div className="p-4 space-y-4 overflow-y-auto flex-1">
            <div className="space-y-2">
              <label className="text-xs text-muted-foreground">ID Поведения</label>
              <input type="text" value="deliver_projectile" readOnly className="w-full bg-background border border-border rounded px-2 py-1.5 text-sm text-muted-foreground" />
            </div>
            <div className="space-y-2">
              <label className="text-xs text-muted-foreground">Скорость (Speed)</label>
              <input type="range" min="0.1" max="5.0" step="0.1" defaultValue="1.4" className="w-full accent-primary" />
              <div className="flex justify-between text-xs text-muted-foreground">
                <span>0.1</span>
                <span className="text-foreground">1.4</span>
                <span>5.0</span>
              </div>
            </div>
            <div className="pt-4 border-t border-border">
              <h2 className="text-xs font-semibold text-muted-foreground uppercase tracking-wider mb-3">3D Предпросмотр</h2>
              <div className="h-64 w-full">
                <VoxelPreview />
              </div>
            </div>
          </div>
        </aside>
      </main>
    </div>
  );
}

export default App;