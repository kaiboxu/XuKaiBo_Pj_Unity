using System.Collections;
using System.Collections.Generic;
using UnityEngine;

#if UNITY_EDITOR
using UnityEditor;
#endif

namespace sunny{
	#if UNITY_EDITOR
	[CustomEditor(typeof(SkyDome))]
	public class SkyDomeEditor : Editor
	{
		public override void OnInspectorGUI()
		{
			DrawDefaultInspector();

			SkyDome myScript = (SkyDome)target;
			if(GUILayout.Button("Generate"))
			{
				myScript.Generate();
			}
		}
	}
	#endif
	[ExecuteInEditMode]
	[RequireComponent(typeof(MeshFilter))]
	public class SkyDome : MonoBehaviour {

		[Range(0.001f,1)]
		public float floorHeight = 0.05f;
		private Mesh mesh;
		[Range(8,100)]
		public int h = 12;
		[Range(8,100)]
		public int v =24;
		public float rotation = 180;
		public bool updateEveryFrame ;

		void Start () {
			Generate ();
		}
		void Update () {
			if(updateEveryFrame)Generate ();
		}

		public void Generate () {
			if (mesh == null) {
				mesh = new Mesh();
			}
			if(updateEveryFrame)mesh.MarkDynamic ();

			int len = (h + 1) * (v + 1);
			Vector3[] vs = new Vector3[len];
			Vector4[] uv = new Vector4[len];
			//Vector3[] normals = new Vector3[len];
			Vector3[] vsR = new Vector3[len];




			for (int i = 0; i<= h; i++) {
				for (int j = 0; j<= v; j++) {
					int index = (i) * (v + 1) + j;
					Vector3 pos = Quaternion.Euler(180*i/(float)h,360*j /(float)v+180+rotation ,0)*Vector3.up;

						uv[index] = new Vector4(pos.x,pos.y,pos.z,Mathf.Clamp01((-floorHeight-pos.y)/(1+floorHeight)));
						pos = Quaternion.Euler(0,rotation ,0)*pos;

					Vector3 posD = pos;
					Vector3 posR = pos;

					if (posR.y < -floorHeight) {
						posD = posR = pos * -floorHeight / pos.y;
						posD.y -= -floorHeight;
						posR.y -= -floorHeight;
					} else {
						posR.y -= -floorHeight;
						posD.y= 0;

					}

					vs[index] = posD;
					vsR[index] = posR;
				}
			}
			int[] tri = new int[(h)*(v)*6];

			for (int i = 0; i < h; i ++) {
				for (int j = 0; j < v; j ++) {
					int index = (i*v+j)*6;
					tri[index+0] = (i)*(v+1)+(j);
					tri[index+1] = (i+1)*(v+1)+(j+1);
					tri[index+2] = (i+1)*(v+1)+(j);
					tri[index+3] = (i)*(v+1)+(j);
					tri[index+4] = (i)*(v+1)+(j+1);
					tri[index+5] = (i+1)*(v+1)+(j+1);
				}
			}
			mesh.Clear ();
			mesh.vertices = vs;
			List<Vector4> list = new List<Vector4> ();
			list.AddRange (uv);
			mesh.SetUVs (0, list);
			List<Vector3> list2 = new List<Vector3> ();
			list2.AddRange (vsR);
			mesh.SetUVs (1, list2);

			mesh.SetTriangles(tri,0);
			mesh.RecalculateNormals ();
				mesh.bounds = new Bounds (new Vector3(0,1,0),new Vector3(2,2,2));
			MeshFilter mF = GetComponent<MeshFilter>();
			mF.sharedMesh = mesh;
			MeshRenderer mR = GetComponent<MeshRenderer>();
			if (mR)
				mR.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
		}
	}
}
