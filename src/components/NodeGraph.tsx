import React, { useCallback } from 'react';
import ReactFlow, { 
  Background, 
  Controls, 
  MiniMap,
  useReactFlow,
  Node,
  type OnNodesChange,
  type OnEdgesChange,
  type OnConnect
} from 'reactflow';
import 'reactflow/dist/style.css';
import { useGraphStore } from '../stores/graphStore';
import type { JutsuNodeData, NodeType } from '../types/jutsu';
import { Plus, Zap, Target, Crosshair, Circle, Activity, Clock, Flag } from 'lucide-react';

// Иконки для разных фаз (визуальная подсказка)
const phaseIcons: Record<string, React.ReactNode> = {
  trigger: <Zap className="w-3 h-3 text-yellow-400" />,
  delivery: <Target className="w-3 h-3 text-blue-400" />,
  contact: <Crosshair className="w-3 h-3 text-red-400" />,
  area: <Circle className="w-3 h-3 text-orange-400" />,
  status: <Activity className="w-3 h-3 text-green-400" />,
  duration: <Clock className="w-3 h-3 text-purple-400" />,
  end: <Flag className="w-3 h-3 text-gray-400" />,
};

// Вспомогательная функция для определения фазы по ID поведения
const getNodePhase = (behaviorId: string): NodeType => {
  if (behaviorId.startsWith('trigger_')) return 'trigger';
  if (behaviorId.startsWith('deliver_')) return 'delivery';
  if (behaviorId.startsWith('impact_')) return 'contact';
  if (behaviorId.startsWith('area_')) return 'area';
  if (behaviorId.startsWith('status_')) return 'status';
  if (behaviorId.startsWith('duration_')) return 'duration';
  if (behaviorId.startsWith('end_')) return 'end';
  return 'delivery'; // fallback
};

// Кастомный стиль для темной темы ReactFlow
const nodeTypes = {}; // Здесь позже будут кастомные компоненты нод

export function NodeGraph() {
  const { nodes, edges, onNodesChange, onEdgesChange, onConnect, addNode } = useGraphStore();
  const reactFlowInstance = useReactFlow(); // КРИТИЧЕСКИ ВАЖНО для точного позиционирования

  const onDragOver = useCallback((event: React.DragEvent) => {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
  }, []);

  const onDrop = useCallback(
    (event: React.DragEvent) => {
      event.preventDefault();

      const type = event.dataTransfer.getData('application/reactflow');
      const label = event.dataTransfer.getData('application/reactflow/label') || type;

      if (!type || !reactFlowInstance) return;

      // 1. Получаем точные координаты относительно холста ReactFlow (а не экрана)
      const position = reactFlowInstance.screenToFlowPosition({
        x: event.clientX,
        y: event.clientY,
      });

      // 2. Создаем новую ноду с правильными типами
      const newNode: Node<JutsuNodeData> = {
        id: `node_${Date.now()}`,
        type: 'default', // Позже заменим на кастимизированные 'triggerNode', 'deliveryNode' и т.д.
        position,
        data: { 
          label, 
          behaviorId: type, 
          params: {}, 
          nodeType: getNodePhase(type) 
        },
      };

      addNode(newNode);
    },
    [addNode, reactFlowInstance]
  );

  return (
    <div className="w-full h-full bg-zinc-950 rounded-lg border border-zinc-800 relative overflow-hidden flex">
      
      {/* Основной холст ReactFlow */}
      <div className="flex-1 h-full relative">
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={onNodesChange as OnNodesChange}
          onEdgesChange={onEdgesChange as OnEdgesChange}
          onConnect={onConnect as OnConnect}
          onDragOver={onDragOver}
          onDrop={onDrop}
          nodeTypes={nodeTypes}
          fitView
          fitViewOptions={{ padding: 0.2 }}
          className="bg-zinc-950"
          proOptions={{ hideAttribution: true }} // Убирает водяной знак ReactFlow (опционально)
        >
          <Background color="#27272a" gap={20} size={1} />
          <Controls className="bg-zinc-900 border-zinc-800 text-zinc-400 hover:text-zinc-100" />
          <MiniMap 
            nodeColor="#ff6b35" 
            maskColor="rgba(0,0,0,0.6)" 
            className="bg-zinc-900 border border-zinc-800 rounded-md"
          />
        </ReactFlow>
      </div>

      {/* Боковая панель (Palette) для перетаскивания */}
      <div className="w-64 border-l border-zinc-800 bg-zinc-900/50 backdrop-blur-sm flex flex-col">
        <div className="p-3 border-b border-zinc-800">
          <h3 className="text-xs font-semibold text-zinc-400 uppercase tracking-wider">Библиотека фаз</h3>
        </div>
        
        <div className="flex-1 overflow-y-auto p-3 space-y-4 custom-scrollbar">
          {/* Триггеры */}
          <div className="space-y-2">
            <h4 className="text-[10px] font-bold text-zinc-500 uppercase flex items-center gap-1">
              <Zap className="w-3 h-3" /> Триггеры
            </h4>
            <DraggableNode type="trigger_handseals" label="Печати рук" />
            <DraggableNode type="trigger_charge" label="Зарядка" />
            <DraggableNode type="trigger_instant" label="Мгновенный" />
          </div>

          {/* Доставка */}
          <div className="space-y-2">
            <h4 className="text-[10px] font-bold text-zinc-500 uppercase flex items-center gap-1">
              <Target className="w-3 h-3" /> Доставка
            </h4>
            <DraggableNode type="deliver_projectile" label="Снаряд" />
            <DraggableNode type="deliver_dash" label="Рывок" />
            <DraggableNode type="deliver_wall" label="Стена" />
          </div>

          {/* Контакт */}
          <div className="space-y-2">
            <h4 className="text-[10px] font-bold text-zinc-500 uppercase flex items-center gap-1">
              <Crosshair className="w-3 h-3" /> Контакт
            </h4>
            <DraggableNode type="impact_damage" label="Урон" />
            <DraggableNode type="impact_explosion" label="Взрыв" />
          </div>
        </div>
      </div>
    </div>
  );
}

// Отдельный компонент для перетаскиваемого элемента (для чистоты кода)
interface DraggableNodeProps {
  type: string;
  label: string;
}

function DraggableNode({ type, label }: DraggableNodeProps) {
  const onDragStart = (event: React.DragEvent) => {
    event.dataTransfer.setData('application/reactflow', type);
    event.dataTransfer.setData('application/reactflow/label', label);
    event.dataTransfer.effectAllowed = 'move';
  };

  return (
    <div
      className="cursor-grab active:cursor-grabbing bg-zinc-800/80 hover:bg-zinc-700 border border-zinc-700 hover:border-zinc-600 text-zinc-200 text-xs px-3 py-2 rounded-md shadow-sm transition-all flex items-center gap-2 select-none"
      draggable
      onDragStart={onDragStart}
    >
      <Plus className="w-3 h-3 text-zinc-500" />
      <span>{label}</span>
    </div>
  );
}