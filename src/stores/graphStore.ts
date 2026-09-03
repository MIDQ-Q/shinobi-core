import { create } from 'zustand';
import { Node, Edge, addEdge, applyNodeChanges, applyEdgeChanges, OnNodesChange, OnEdgesChange, OnConnect } from 'reactflow';
import { JutsuNodeData, Voxel } from '../types/jutsu';

interface GraphState {
  nodes: Node<JutsuNodeData>[];
  edges: Edge[];
  voxelModel: Voxel[];
  
  onNodesChange: OnNodesChange;
  onEdgesChange: OnEdgesChange;
  onConnect: OnConnect;
  
  addNode: (node: Node<JutsuNodeData>) => void;
  updateNodeParams: (nodeId: string, params: Record<string, any>) => void;
  setVoxelModel: (model: Voxel[]) => void;
  clearGraph: () => void;
}

// Пример воксельной модели (Огненный шар 3x3x3)
const initialVoxelModel: Voxel[] = [];
for(let x=-1; x<=1; x++) {
  for(let y=-1; y<=1; y++) {
    for(let z=-1; z<=1; z++) {
      initialVoxelModel.push({
        x, y, z,
        color: Math.random() > 0.5 ? '#ff6b35' : '#ff9f1c'
      });
    }
  }
}

export const useGraphStore = create<GraphState>((set, get) => ({
  nodes: [
    {
      id: '1',
      type: 'default',
      position: { x: 100, y: 100 },
      data: { label: 'Печати рук', behaviorId: 'trigger_handseals', params: { sealCount: 3 }, nodeType: 'trigger' },
    },
    {
      id: '2',
      type: 'default',
      position: { x: 400, y: 100 },
      data: { label: 'Снаряд', behaviorId: 'deliver_projectile', params: { speed: 1.4, size: 0.5 }, nodeType: 'delivery' },
    }
  ],
  edges: [
    { id: 'e1-2', source: '1', target: '2', animated: true }
  ],
  voxelModel: initialVoxelModel,

  onNodesChange: (changes) => set({ nodes: applyNodeChanges(changes, get().nodes) }),
  onEdgesChange: (changes) => set({ edges: applyEdgeChanges(changes, get().edges) }),
  onConnect: (connection) => set({ edges: addEdge(connection, get().edges) }),

  addNode: (node) => set((state) => ({ nodes: [...state.nodes, node] })),
  
  updateNodeParams: (nodeId, params) => set((state) => ({
    nodes: state.nodes.map((n) => 
      n.id === nodeId ? { ...n, data: { ...n.data, params: { ...n.data.params, ...params } } } : n
    )
  })),

  setVoxelModel: (model) => set({ voxelModel: model }),
  clearGraph: () => set({ nodes: [], edges: [], voxelModel: [] }),
}));