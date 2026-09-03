// Типы для графа узлов
export type NodeType = 'trigger' | 'delivery' | 'contact' | 'area' | 'status' | 'end' | 'modifier';

export interface JutsuNodeData {
  label: string;
  behaviorId: string;
  params: Record<string, any>;
  nodeType: NodeType;
}

// Типы для воксельной модели
export interface Voxel {
  x: number;
  y: number;
  z: number;
  color: string; // hex, e.g., "#ff6b35"
}

export interface JutsuDefinition {
  id: string;
  name: string;
  nodes: any[]; // ReactFlow Node[]
  edges: any[]; // ReactFlow Edge[]
  voxelModel: Voxel[];
}