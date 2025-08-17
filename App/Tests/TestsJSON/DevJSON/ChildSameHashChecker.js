const fs = require('fs');

class NodeChildrenHashComparer {
    constructor(filePath) {
        this.filePath = filePath;
        this.data = null;
        this.outputDir = './node_comparisons'; // Directory for output files
    }

    readJsonFile() {
        try {
            const jsonData = fs.readFileSync(this.filePath, 'utf8');
            this.data = JSON.parse(jsonData);
            return true;
        } catch (error) {
            console.error('Error reading JSON file:', error.message);
            return false;
        }
    }

    createOutputDirectory() {
        if (!fs.existsSync(this.outputDir)) {
            fs.mkdirSync(this.outputDir);
        }
    }

    saveNodeToFile(nodeId, nodeData) {
        try {
            const fileName = `${this.outputDir}/${nodeId}.json`;
            fs.writeFileSync(fileName, JSON.stringify(nodeData, null, 2));
        } catch (error) {
            console.error(`Error saving node ${nodeId} to file:`, error.message);
        }
    }

    getChildrenStructure(node) {
        const structure = {
            sequence: [],
            branches: {}
        };

        if (node.sequence) {
            structure.sequence = node.sequence.map(child => ({
                type: child.type,
                componentType: child.componentType,
                name: child.name,
                properties: child.properties
            }));
        }

        if (node.branches) {
            Object.entries(node.branches).forEach(([key, branch]) => {
                if (Array.isArray(branch)) {
                    structure.branches[key] = branch.map(child => ({
                        type: child.type,
                        componentType: child.componentType,
                        name: child.name,
                        properties: child.properties
                    }));
                }
            });
        }

        return structure;
    }

    findNodesWithSameChildrenHash(node = this.data, hashMap = new Map()) {
        if (!node) return hashMap;

        if (node.nodeChildrenHash) {
            if (!hashMap.has(node.nodeChildrenHash)) {
                hashMap.set(node.nodeChildrenHash, []);
            }
            hashMap.get(node.nodeChildrenHash).push({
                id: node.id,
                node: node
            });
        }

        if (node.sequence) {
            node.sequence.forEach(child => this.findNodesWithSameChildrenHash(child, hashMap));
        }

        if (node.branches) {
            Object.values(node.branches).forEach(branch => {
                if (Array.isArray(branch)) {
                    branch.forEach(child => this.findNodesWithSameChildrenHash(child, hashMap));
                }
            });
        }

        return hashMap;
    }

    compareChildrenStructures(node1, node2) {
        const structure1 = this.getChildrenStructure(node1);
        const structure2 = this.getChildrenStructure(node2);
        return JSON.stringify(structure1) === JSON.stringify(structure2);
    }

    analyzeNodeGroups() {
        this.createOutputDirectory(); // Create output directory
        const hashMap = this.findNodesWithSameChildrenHash();
        const results = [];

        hashMap.forEach((nodes, nodeChildrenHash) => {
            if (nodes.length > 1) {
                const firstNode = nodes[0].node;
                const differentNodes = [];

                // Save first node
                this.saveNodeToFile(firstNode.id, firstNode);

                for (let i = 1; i < nodes.length; i++) {
                    if (!this.compareChildrenStructures(firstNode, nodes[i].node)) {
                        differentNodes.push(nodes[i].id);
                        // Save different nodes
                        this.saveNodeToFile(nodes[i].id, nodes[i].node);
                    }
                }

                if (differentNodes.length > 0) {
                    results.push({
                        nodeChildrenHash,
                        totalNodes: nodes.length,
                        differentNodeIds: differentNodes,
                        referenceNodeId: firstNode.id
                    });
                }
            }
        });

        return results;
    }
}

function printResults(results) {
    if (results.length === 0) {
        console.log('No inconsistencies found.');
        return;
    }

    results.forEach(group => {
        console.log(`nodeChildrenHash: ${group.nodeChildrenHash}`);
        console.log(`Total nodes: ${group.totalNodes}`);
        console.log(`Reference node ID: ${group.referenceNodeId}`);
        console.log(`Different node IDs: ${group.differentNodeIds.join(', ')}`);
        console.log(`JSON files created in ./node_comparisons directory`);
        console.log('---');
    });
}

// Usage
function main() {
    const filePath = './qacthueK3AdDSjjmoKSh.json';
    const comparer = new NodeChildrenHashComparer(filePath);
    
    if (!comparer.readJsonFile()) {
        return;
    }

    const results = comparer.analyzeNodeGroups();
    printResults(results);
}

main();
