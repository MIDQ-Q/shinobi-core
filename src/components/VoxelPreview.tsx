import { Canvas } from '@react-three/fiber';
import { OrbitControls, Grid, Html } from '@react-three/drei';
import { useGraphStore } from '../stores/graphStore';

function VoxelModel() {
  const voxels = useGraphStore((state) => state.voxelModel);
  
  return (
    <group>
      {voxels.map((voxel, index) => (
        <mesh key={index} position={[voxel.x, voxel.y, voxel.z]}>
          <boxGeometry args={[0.95, 0.95, 0.95]} />
          <meshStandardMaterial color={voxel.color} roughness={0.4} metalness={0.1} />
        </mesh>
      ))}
    </group>
  );
}

export function VoxelPreview() {
  return (
    <div className="w-full h-full bg-zinc-950 rounded-lg border border-zinc-800 overflow-hidden relative">
      <div className="absolute top-2 left-2 z-10 bg-black/50 px-2 py-1 rounded text-xs text-zinc-400 backdrop-blur-sm">
        Воксельный предпросмотр (LMB: Вращать, RMB: Панорама, Scroll: Зум)
      </div>
      <Canvas camera={{ position: [5, 5, 5], fov: 45 }}>
        <color attach="background" args={['#09090b']} />
        <ambientLight intensity={0.6} />
        <directionalLight position={[10, 10, 5]} intensity={1.2} castShadow />
        <pointLight position={[-5, 5, -5]} intensity={0.5} color="#ff6b35" />
        
        <Grid 
          args={[20, 20]} 
          cellSize={1} 
          cellThickness={1} 
          cellColor="#27272a" 
          sectionSize={5} 
          sectionThickness={2} 
          sectionColor="#3f3f46" 
          fadeDistance={25} 
        />
        
        <VoxelModel />
        
        <OrbitControls makeDefault minDistance={2} maxDistance={15} />
      </Canvas>
    </div>
  );
}