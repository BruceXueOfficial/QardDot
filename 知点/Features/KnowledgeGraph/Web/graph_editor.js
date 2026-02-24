(function () {
  const ReactFlowLib = window.ReactFlow;
  if (!ReactFlowLib || !window.React || !window.ReactDOM) {
    const root = document.getElementById("root");
    if (root) {
      root.innerHTML =
        "<div style='padding:20px;color:#1f3355;font-size:13px;'>React Flow 资源加载失败，请检查网络。</div>";
    }
    return;
  }

  const React = window.React;
  const ReactDOM = window.ReactDOM;

  const e = React.createElement;
  const {
    ReactFlow,
    ReactFlowProvider,
    Background,
    Controls,
    MarkerType,
  } = ReactFlowLib;

  function post(payload) {
    try {
      if (
        window.webkit &&
        window.webkit.messageHandlers &&
        window.webkit.messageHandlers.graphBridge
      ) {
        window.webkit.messageHandlers.graphBridge.postMessage(payload);
      }
    } catch (_) {}
  }

  function normalizePayload(payload) {
    if (!payload) return null;
    if (typeof payload === "string") {
      try {
        return JSON.parse(payload);
      } catch (_) {
        return null;
      }
    }
    return payload;
  }

  function clamp(n, min, max) {
    return Math.max(min, Math.min(max, n));
  }

  function buildLabel(title, chip, selected) {
    return e(
      "div",
      {
        className: selected ? "rf-node-card selected" : "rf-node-card",
      },
      [
        e("div", { className: "rf-node-title", key: "title" }, title),
        e(
          "div",
          { className: "rf-node-meta", key: "meta" },
          [e("span", { className: "rf-node-chip", key: "chip" }, chip)]
        ),
      ]
    );
  }

  function makeNode(item, selectedNodeID) {
    const selected = selectedNodeID && selectedNodeID === item.id;
    const tags = Array.isArray(item.tags) ? item.tags : [];

    const chipText = tags.length > 0 ? tags[0] : "知识卡片";
    const title = item.title || "未命名卡片";

    return {
      id: item.id,
      position: {
        x: clamp(Number(item.x || 0), -6000, 6000),
        y: clamp(Number(item.y || 0), -6000, 6000),
      },
      draggable: true,
      selectable: false,
      data: {
        title: title,
        chip: chipText,
        label: buildLabel(title, chipText, selected),
      },
      style: {
        border: "none",
        background: "transparent",
        padding: 0,
        boxShadow: "none",
      },
    };
  }

  function makeEdge(item) {
    return {
      id: item.id,
      source: item.sourceNodeID,
      target: item.targetNodeID,
      label: item.label || "",
      labelStyle: {
        fill: "#2b4b79",
        fontWeight: 600,
        fontSize: 10,
      },
      labelBgStyle: {
        fill: "rgba(255,255,255,0.9)",
        stroke: "rgba(66,114,180,0.3)",
        strokeWidth: 1,
      },
      labelBgPadding: [6, 3],
      labelBgBorderRadius: 999,
      markerEnd: {
        type: MarkerType.ArrowClosed,
      },
      style: {
        strokeWidth: 1.6,
        stroke: "#4470b8",
      },
      selectable: false,
    };
  }

  function GraphApp() {
    const [nodes, setNodes] = React.useState([]);
    const [edges, setEdges] = React.useState([]);
    const [selectedNodeID, setSelectedNodeID] = React.useState(null);
    const viewportRef = React.useRef({ zoom: 1, offsetX: 0, offsetY: 0 });
    const flowRef = React.useRef(null);

    const applyGraph = React.useCallback(
      (payloadInput) => {
        const payload = normalizePayload(payloadInput);
        if (!payload) return;

        const selected = selectedNodeID;
        const nextNodes = (payload.nodes || []).map((item) => makeNode(item, selected));
        const nextEdges = (payload.edges || []).map(makeEdge);

        setNodes(nextNodes);
        setEdges(nextEdges);

        const vp = payload.viewport || { zoom: 1, offsetX: 0, offsetY: 0 };
        viewportRef.current = {
          zoom: clamp(Number(vp.zoom || 1), 0.35, 2.2),
          offsetX: clamp(Number(vp.offsetX || 0), -6000, 6000),
          offsetY: clamp(Number(vp.offsetY || 0), -6000, 6000),
        };

        if (flowRef.current && flowRef.current.setViewport) {
          flowRef.current.setViewport(
            {
              x: viewportRef.current.offsetX,
              y: viewportRef.current.offsetY,
              zoom: viewportRef.current.zoom,
            },
            { duration: 0 }
          );
        }
      },
      [selectedNodeID]
    );

    const applySelection = React.useCallback(
      (value) => {
        const nodeID = typeof value === "string" ? value : null;
        setSelectedNodeID(nodeID);
        setNodes((prev) =>
          prev.map((node) => {
            const selected = node.id === nodeID;
            return {
              ...node,
              data: {
                ...node.data,
                label: buildLabel(node.data.title, node.data.chip, selected),
              },
            };
          })
        );
      },
      [setNodes]
    );

    React.useEffect(() => {
      window.bootstrapGraph = function (payload) {
        applyGraph(payload);
      };
      window.applyGraphPatch = function (payload) {
        applyGraph(payload);
      };
      window.setSelection = function (nodeID) {
        applySelection(nodeID);
      };

      post({ type: "ready" });

      return () => {
        delete window.bootstrapGraph;
        delete window.applyGraphPatch;
        delete window.setSelection;
      };
    }, [applyGraph, applySelection]);

    const handleNodeClick = React.useCallback((event, node) => {
      event.preventDefault();
      setSelectedNodeID(node.id);
      setNodes((prev) =>
        prev.map((n) => {
          const selected = n.id === node.id;
          return {
            ...n,
            data: {
              ...n.data,
              label: buildLabel(n.data.title, n.data.chip, selected),
            },
          };
        })
      );
      post({ type: "selectionChanged", nodeID: node.id });
    }, []);

    const handlePaneClick = React.useCallback(() => {
      setSelectedNodeID(null);
      setNodes((prev) =>
        prev.map((n) => {
          return {
            ...n,
            data: {
              ...n.data,
              label: buildLabel(n.data.title, n.data.chip, false),
            },
          };
        })
      );
      post({ type: "canvasTapped" });
    }, []);

    const handleNodeDragStop = React.useCallback((_, node) => {
      post({
        type: "nodePositionsChanged",
        positions: [
          {
            nodeID: node.id,
            x: Number(node.position.x || 0),
            y: Number(node.position.y || 0),
          },
        ],
      });
    }, []);

    const handleMoveEnd = React.useCallback((_, viewport) => {
      post({
        type: "viewportChanged",
        viewport: {
          zoom: Number(viewport.zoom || 1),
          offsetX: Number(viewport.x || 0),
          offsetY: Number(viewport.y || 0),
        },
      });
    }, []);

    const handleEdgeClick = React.useCallback((event, edge) => {
      event.preventDefault();
      post({ type: "edgeTapped", edgeID: edge.id });
    }, []);

    return e(
      "div",
      { className: "graph-shell" },
      e(
        ReactFlow,
        {
          nodes: nodes,
          edges: edges,
          onNodeClick: handleNodeClick,
          onNodeDragStop: handleNodeDragStop,
          onPaneClick: handlePaneClick,
          onMoveEnd: handleMoveEnd,
          onEdgeClick: handleEdgeClick,
          onInit: function (instance) {
            flowRef.current = instance;
            if (viewportRef.current) {
              instance.setViewport(
                {
                  x: viewportRef.current.offsetX,
                  y: viewportRef.current.offsetY,
                  zoom: viewportRef.current.zoom,
                },
                { duration: 0 }
              );
            }
          },
          minZoom: 0.35,
          maxZoom: 2.2,
          panOnDrag: true,
          zoomOnPinch: true,
          zoomOnScroll: true,
          selectionOnDrag: false,
          nodesConnectable: false,
          elementsSelectable: false,
          fitView: false,
          proOptions: { hideAttribution: true },
          translateExtent: [
            [-6000, -6000],
            [6000, 6000],
          ],
          defaultEdgeOptions: {
            markerEnd: {
              type: MarkerType.ArrowClosed,
            },
          },
        },
        [
          e(Background, {
            key: "bg",
            color: "rgba(85, 135, 205, 0.18)",
            gap: 24,
          }),
          e(Controls, { key: "controls", showInteractive: false }),
        ]
      )
    );
  }

  ReactDOM.createRoot(document.getElementById("root")).render(
    e(ReactFlowProvider, null, e(GraphApp))
  );
})();
