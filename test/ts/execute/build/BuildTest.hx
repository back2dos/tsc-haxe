package ts.execute.build;

import go.Fmt;
import go.Slices;
import ts.core.Core;
import ts.tsoptions.Tsoptions;
import ts.execute.tsctests.Tsctests;
import ts.execute.build.Orchestrator;

// Port of internal/execute/build/graph_test.go (package build_test).

@:structInit
class BuildOrderTestCase {
	public var name:String = "";
	public var projects:Null<Array<String>> = null;
	public var expected:Null<Array<String>> = null;
	public var circular:Bool = false;

	function configName(project:String):String {
		return Fmt.Sprintf("/home/src/workspaces/project/%s/tsconfig.json", [project]);
	}

	function projectName(config:String):String {
		var str = StringTools.startsWith(config, "/home/src/workspaces/project/") ? config.substring("/home/src/workspaces/project/".length) : config;
		str = StringTools.endsWith(str, "/tsconfig.json") ? str.substring(0, str.length - "/tsconfig.json".length) : str;
		return str;
	}

	// PORT: assert.Assert / assert.DeepEqual → T.isTrue / T.eq on the joined lists.
	public function run():Void {
		T.run(this.name + " - " + this.projects.join(","), function() {
			final files = new Map<String, Any>();
			final deps:Map<String, Array<String>> = [
				"A" => ["B", "C"],
				"B" => ["C", "D"],
				"C" => ["D", "E"],
				"F" => ["E"],
				"H" => ["I"],
				"I" => ["J"],
				"J" => ["H", "E"],
			];
			// PORT: Go ranges over a map (random order); the lists are only used with Contains.
			final reverseDeps = new Map<String, Array<String>>();
			for (project => deps in deps) {
				for (dep in deps) {
					if (!reverseDeps.exists(dep))
						reverseDeps.set(dep, []);
					reverseDeps.get(dep).push(project);
				}
			}
			final verifyDeps = function(orchestrator:Orchestrator, buildOrder:Array<String>, hasDownStream:Bool) {
				for (index in 0...buildOrder.length) {
					final project = buildOrder[index];
					final upstream = Core.Map(orchestrator.Upstream(this.configName(project)), this.projectName);
					final expectedUpstream = deps.get(project);
					T.isTrue(Core.len(upstream) <= Core.len(expectedUpstream),
						Fmt.Sprintf("Expected upstream for %s to be at most %d, got %d", [project, Core.len(expectedUpstream), Core.len(upstream)]));
					for (expected in expectedUpstream) {
						if (Slices.Contains(buildOrder.slice(0, index), expected)) {
							T.isTrue(Slices.Contains(upstream, expected), Fmt.Sprintf("Expected upstream for %s to contain %s", [project, expected]));
						} else {
							T.isTrue(!Slices.Contains(upstream, expected), Fmt.Sprintf("Expected upstream for %s to not contain %s", [project, expected]));
						}
					}

					final downstream = Core.Map(orchestrator.Downstream(this.configName(project)), this.projectName);
					final expectedDownstream = Core.IfElse(hasDownStream, reverseDeps.get(project), null);
					T.isTrue(Core.len(downstream) <= Core.len(expectedDownstream),
						Fmt.Sprintf("Expected downstream for %s to be at most %d, got %d", [project, Core.len(expectedDownstream), Core.len(downstream)]));
					for (expected in expectedDownstream) {
						if (Slices.Contains(buildOrder.slice(index + 1), expected)) {
							T.isTrue(Slices.Contains(downstream, expected), Fmt.Sprintf("Expected downstream for %s to contain %s", [project, expected]));
						} else {
							T.isTrue(!Slices.Contains(downstream, expected), Fmt.Sprintf("Expected downstream for %s to not contain %s", [project, expected]));
						}
					}
				}
			};
			for (project in ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]) {
				files.set(Fmt.Sprintf("/home/src/workspaces/project/%s/%s.ts", [project, project]), "export {}");
				var referencesStr = "";
				if (deps.exists(project)) {
					referencesStr = Fmt.Sprintf(", \"references\": [%s]", [deps.get(project).map(function(dep:String):String {
						return Fmt.Sprintf("{ \"path\": \"../%s\" }", [dep]);
					}).join(",")]);
				}
				files.set(this.configName(project), Fmt.Sprintf("{
                \"compilerOptions\": { \"composite\": true },
                \"files\": [\"./%s.ts\"],
                %s
            }", [project, referencesStr]));
			}

			final sys = Tsctests.NewTscSystem(files, true, "/home/src/workspaces/project");
			final args = ["--build", "--dry"].concat(this.projects);
			final buildCommand = Tsoptions.ParseBuildCommandLine(args, sys);
			final options = new Options();
			options.Sys = sys;
			options.Command = buildCommand;
			var orchestrator = Build.NewOrchestrator(options);
			orchestrator.GenerateGraph(null);
			final buildOrder = Core.Map(orchestrator.Order(), this.projectName);
			T.eq(this.expected.join(","), buildOrder.join(","));
			verifyDeps(orchestrator, buildOrder, false);

			if (!this.circular) {
				for (project => projectDeps in deps) {
					final child = this.configName(project);
					final childIndex = buildOrder.indexOf(child);
					if (childIndex == -1) {
						continue;
					}
					for (dep in projectDeps) {
						final parent = this.configName(dep);
						final parentIndex = buildOrder.indexOf(parent);

						T.isTrue(childIndex > parentIndex, Fmt.Sprintf("Expecting child %s to be built after parent %s", [project, dep]));
					}
				}
			}

			orchestrator.GenerateGraphReusingOldTasks();
			final buildOrder2 = Core.Map(orchestrator.Order(), this.projectName);
			T.eq(this.expected.join(","), buildOrder2.join(","));

			final argsWatch = ["--build", "--watch"].concat(this.projects);
			final buildCommandWatch = Tsoptions.ParseBuildCommandLine(argsWatch, sys);
			final optionsWatch = new Options();
			optionsWatch.Sys = sys;
			optionsWatch.Command = buildCommandWatch;
			orchestrator = Build.NewOrchestrator(optionsWatch);
			orchestrator.GenerateGraph(null);
			final buildOrder3 = Core.Map(orchestrator.Order(), this.projectName);
			verifyDeps(orchestrator, buildOrder3, true);
		});
	}
}

class BuildTest {
	public static function run() {
		TestBuildOrderGenerator();
	}

	public static function TestBuildOrderGenerator() {
		final testCases:Array<BuildOrderTestCase> = [
			{name: "specify two roots", projects: ["A", "G"], expected: ["D", "E", "C", "B", "A", "G"], circular: false},
			{name: "multiple parts of the same graph in various orders", projects: ["A"], expected: ["D", "E", "C", "B", "A"], circular: false},
			{name: "multiple parts of the same graph in various orders", projects: ["A", "C", "D"], expected: ["D", "E", "C", "B", "A"], circular: false},
			{name: "multiple parts of the same graph in various orders", projects: ["D", "C", "A"], expected: ["D", "E", "C", "B", "A"], circular: false},
			{name: "other orderings", projects: ["F"], expected: ["E", "F"], circular: false},
			{name: "other orderings", projects: ["E"], expected: ["E"], circular: false},
			{name: "other orderings", projects: ["F", "C", "A"], expected: ["E", "F", "D", "C", "B", "A"], circular: false},
			{name: "returns circular order", projects: ["H"], expected: ["E", "J", "I", "H"], circular: true},
			{name: "returns circular order", projects: ["A", "H"], expected: ["D", "E", "C", "B", "A", "J", "I", "H"], circular: true},
		];
		for (testcase in testCases) {
			testcase.run();
		}
	}
}
