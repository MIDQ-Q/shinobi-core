import React, { useCallback } from 'react';
import ReactFlow, { 
  Background, 
  Controls, 
  MiniMap,
  useReactFlow,
  Node
} from 'reactflow';
import 'reactflow/dist/style.css';
import { useGraphStore, JutsuNodeData } from '../stores/graphStore';
import { Plus, Zap, Target, Crosshair } from 'lucide-react';

const phaseIcons: Record<string, React.ReactNode> = {
  trigger: <Zap className="w-3 h-3 text-yellow-400" />,
  delivery: <Target className="w-3 h-3 text-blue-400" />,
  contact: <Crosshair className="w-3 h-3 text-red-400" />,
};

const getNodePhase = (behaviorId: string): JutsuNodeData['nodeType'] => {
  if (behaviorId.startsWith('trigger_')) return 'trigger';
  if (behaviorId.startsWith('deliver_')) return 'delivery';
  if (behaviorId.startsWith('impact_')) return 'contact';
  return 'delivery';
};

export function NodeGraph() {
  const { nodes, edges, onNodesChange, onEdgesChange, onConnect, addNode } = useGraphStore();
  const reactFlowInstance = useReactFlow();

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

      const position = reactFlowInstance.screenToFlowPosition({
        x: event.clientX,
        y: event.clientY,
      });

      const newNode: Node<JutsuNodeData> = {
        id: `node_${Date.now()}`,
        type: 'default',
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
      <div className="flex-1 h-full relative">
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          onConnect={onConnect}
          onDragOver={onDragOver}
          onDrop={onDrop}
          fitView
          className="bg-zinc-950"
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

      <div className="w-64 border-l border-zinc-800 bg-zinc-900/50 backdrop-blur-sm flex flex-col">
        <div className="p-3 border-b border-zinc-800">
          <h3 className="text-xs font-semibold text-zinc-400 uppercase tracking-wider">Библиотека фаз</h3>
        </div>
        
        <div className="flex-1 overflow-y-auto p-3 space-y-4">
          <div className="space-y-2">
            <h4 className="text-[10px] font-bold text-zinc-500 uppercase flex items-center gap-1">
              <Zap className="w-3 h-3" /> Триггеры
            </h4>
            <DraggableNode type="trigger_handseals" label="Печати рук" />
            <DraggableNode type="trigger_charge" label="Зарядка" />
          </div>

          <div className="space-y-2">
            <h4 className="text-[10px] font-bold text-zinc-500 uppercase flex items-center gap-1">
              <Target className="w-3 h-3" /> Доставка
            </h4>
            <DraggableNode type="deliver_projectile" label="Снаряд" />
            <DraggableNode type="deliver_dash" label="Рывок" />
          </div>
        </div>
      </div>
    </div>
  );
}

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