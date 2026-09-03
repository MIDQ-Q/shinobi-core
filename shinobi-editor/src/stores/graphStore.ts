import { create } from 'zustand';
import { 
  Node, 
  Edge, 
  addEdge, 
  applyNodeChanges, 
  applyEdgeChanges, 
  OnNodesChange, 
  OnEdgesChange, 
  OnConnect 
} from 'reactflow';

export interface JutsuNodeData {
  label: string;
  behaviorId: string;
  params: Record<string, any>;
  nodeType: 'trigger' | 'delivery' | 'contact' | 'area' | 'status' | 'end' | 'modifier';
}

interface GraphState {
  nodes: Node<JutsuNodeData>[];
  edges: Edge[];
  
  onNodesChange: OnNodesChange;
  onEdgesChange: OnEdgesChange;
  onConnect: OnConnect;
  
  addNode: (node: Node<JutsuNodeData>) => void;
  updateNodeParams: (nodeId: string, params: Record<string, any>) => void;
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

  onNodesChange: (changes) => set({ nodes: applyNodeChanges(changes, get().nodes) }),
  onEdgesChange: (changes) => set({ edges: applyEdgeChanges(changes, get().edges) }),
  onConnect: (connection) => set({ edges: addEdge(connection, get().edges) }),

  addNode: (node) => set((state) => ({ nodes: [...state.nodes, node] })),
  
  updateNodeParams: (nodeId, params) => set((state) => ({
    nodes: state.nodes.map((n) => 
      n.id === nodeId ? { ...n, data: { ...n.data, params: { ...n.data.params, ...params } } } : n
    )
  })),
}));