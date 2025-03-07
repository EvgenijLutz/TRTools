//
//  ContentView.swift
//  WAD Editor
//
//  Created by Evgenij Lutz on 29.01.24.
//

import SwiftUI
import WADKit
import Lemur
import Observation
import Combine
import Cashmere


enum MeshType {
    case standard
    case shaded
    case weighted
}


enum EditorItemType {
    case section
    
    case texturePage(_ texturePage: WKTexturePage)
    case mesh(_ mesh: Int, type: MeshType)
    
    case model(_ model: Int)
    case animation(model: Int, animation: Int)
    
    case staticObject(_ staticObject: WKStaticObject)
}


struct NavigatorItem: Identifiable, Hashable {
    var id = UUID()
        
    var name: String
    var value: EditorItemType
    var items: [NavigatorItem]? = nil
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static nonisolated func == (lhs: NavigatorItem, rhs: NavigatorItem) -> Bool {
        return lhs.id == rhs.id
    }
}


@MainActor
protocol NavigatorItemProviderDelegate: AnyObject {
    func navigatorItemSetItems(_ items: [NavigatorItem])
}


@MainActor
class NavigatorItemProvider {
    weak var delegate: NavigatorItemProviderDelegate?
}


@MainActor
@Observable class ViewModel {
    let editor = Editor()
    
    //@Published var path: NavigationPath
    let provider = NavigatorItemProvider()
    
    
    var navigatorList: [NavigatorItem] = []
    var selection: UUID? = nil
    
    
    init() {
    }
    
    
    func loadTestData() async {
        await editor.loadTestData()
        
        reload()
    }
    
    
    func loadWAD(at url: URL) {
        editor.clear()
        reload()
        
        Task {
            let timeTaken = await ContinuousClock().measure {
                await editor.loadData(at: url)
            }
            print("Import time taken: \(timeTaken)")
            
            reload()
        }
    }
    
    
    func reload() {
        guard let wad = editor.wad else {
            navigatorList = []
            provider.delegate?.navigatorItemSetItems(navigatorList)
            return
        }
        
        navigatorList = [
            .init(name: "Texture pages", value: .section, items:
                    wad.texturePages.enumerated().map({ index, page in
                        return NavigatorItem(name: "Page #\(index)", value: .texturePage(page))
                    })
                 ),
            
                .init(name: "Meshes", value: .section, items: editor.meshConnections/*.prefix(30)*/.enumerated().map { index, item in
                    let badge: String = {
                        guard item.meshes.isEmpty && item.shadedMeshes.isEmpty && item.weightedMeshes.isEmpty else {
                            return ""
                        }
                        
                        return " ⚠️ [\(item.meshes.count)]"
                    }()
                    let type: MeshType = item.meshes.isEmpty ? .shaded : .standard
                    return NavigatorItem(name: "Mesh\(badge) #\(index)", value: .mesh(index, type: type))
                }),
            
                .init(name: "Models", value: .section, items: wad.models/*.prefix(30)*/.enumerated().map({ (modelIndex, model) in
                    let name = String(describing: model.identifier)
                    return NavigatorItem(name: name, value: .model(modelIndex), items: [
                        .init(name: "Skeleton", value: .section),
                        .init(name: "Animations", value: .section, items: model.animations/*.prefix(30)*/.enumerated().map({ (animationIndex, animation) in
                                .init(name: "Animation #\(animationIndex)", value: .animation(model: modelIndex, animation: animationIndex))
                        }))
                    ])
                })),
            
                .init(name: "Statics", value: .section, items: wad.staticObjects.map({ staticObject in
                    let name = String(describing: staticObject.identifier)
                    return NavigatorItem(name: name, value: .staticObject(staticObject))
                }))
        ]
        
        
        //selection = navigatorList.first?.items?.first?.id
        provider.delegate?.navigatorItemSetItems(navigatorList)
    }
    
    
    private func findItem(in list: [NavigatorItem]?, selection: UUID?) -> NavigatorItem? {
        guard let list, let selection else {
            return nil
        }
        
        for item in list {
            if item.id == selection {
                return item
            }
            
            if let item = findItem(in: item.items, selection: selection) {
                return item
            }
        }
        
        return nil
    }
    
    
    func updateCurrentSelection() {
        guard let item = findItem(in: navigatorList, selection: selection) else {
            return
        }
        
        switch item.value {
        case .section:
            editor.canvas.opaqueMeshes = []
            editor.canvas.shadedMeshes = []
            editor.canvas.weightedMeshes = []
            
        case .texturePage(_):
            editor.canvas.opaqueMeshes = []
            editor.canvas.shadedMeshes = []
            editor.canvas.weightedMeshes = []
            
        case .mesh(let mesh, _):
            let info = editor.findMeshInfo(mesh)
            editor.canvas.opaqueMeshes = info.opaque.map { .init(mesh: $0) }
            editor.canvas.shadedMeshes = info.shaded.map { .init(mesh: $0) }
            editor.canvas.weightedMeshes = info.weighted.map { .init(mesh: $0) }
            
        case .model(let model):
            editor.showModel(modelIndex: model)
            
        case .animation(let modelIndex, let animationIndex):
            editor.showModel(modelIndex: modelIndex, animationIndex: animationIndex)
            
        case .staticObject(let staticObject):
            let info = editor.findMeshInfo(staticObject.mesh)
            editor.canvas.opaqueMeshes = info.opaque.map { .init(mesh: $0) }
            editor.canvas.shadedMeshes = info.shaded.map { .init(mesh: $0) }
            editor.canvas.weightedMeshes = info.weighted.map { .init(mesh: $0) }
        }
        
    }
}


struct TransferItem: Transferable, Equatable, Sendable {
    
    public var url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .item) { item in
            let name = item.file.lastPathComponent
            let tmpUrl = FileManager.default.temporaryDirectory.appending(component: name)
            if FileManager.default.fileExists(atPath: tmpUrl.path()) {
                try FileManager.default.removeItem(at: tmpUrl)
            }
            
            try FileManager.default.copyItem(at: item.file, to: tmpUrl)
            
            return .init(url: tmpUrl)
        }
//        FileRepresentation(contentType: .item) { item in
//            SentTransferredFile(item.url)
//        } importing: { received in
//            @Dependency(\.fileClient) var fileClient
//            let temporaryFolder = fileClient.temporaryReplacementDirectory(received.file)
//            let temporaryURL = temporaryFolder.appendingPathComponent(received.file.lastPathComponent)
//            let url = try fileClient.copyItemToUniqueURL(at: received.file, to: temporaryURL)
//            return Self(url)
//        }
    }
}


struct ContentView: View {
    @State var viewModel = ViewModel()
    
    @State var meshesExpanded: Bool = true
    @State var path = NavigationPath()
    
    @State var timelineVisible: Bool = false
    
    
    var body: some View {
        NavigationSplitView {
#if true
            NavigatorTestView(dataProvider: viewModel.provider) { item in
                viewModel.selection = item.id
                viewModel.updateCurrentSelection()
            }
            .ignoresSafeArea()
            .navigationTitle("WAD Editor")
#elseif true
            // Combinatoric hell
            List(selection: $viewModel.selection) {
                OutlineGroup(viewModel.navigatorList, children: \.items) { item in
                    //Text(item.name)
                    NavigationLink(item.name, value: item.id)
                }
            }
            .onChange(of: viewModel.selection) { oldValue, newValue in
                viewModel.updateCurrentSelection()
            }
            .navigationTitle("WAD Editor")
#else
            Table(of: ViewModel.MeshItem.self, selection: $viewModel.selection) {
                TableColumn("Name") { item in
                    HStack {
                        Image(systemName: "chevron.forward")
                            .rotationEffect(.degrees(item.expanded ? 90 : 0))
                            .opacity(item.items.isEmpty ? 0 : 1)
                            .onTapGesture {
                                guard let index = viewModel.meshesList.firstIndex(where: { $0.id == item.id }) else {
                                    return
                                }
                                
                                withAnimation {
                                    viewModel.meshesList[index].expanded.toggle()
                                }
                            }
                        
                        Text(item.name)
                        //NavigationLink(item.name, value: item.id)
                    }
                    .transition(.slide)
                }
            } rows: {
                ForEach(viewModel.meshesList) { item in
                    TableRow(item)
                    if item.expanded {
                        ForEach(item.items) { child in
                            TableRow(child)
                        }
                    }
                }
            }
            .tableColumnHeaders(.hidden)
            .onChange(of: viewModel.selection) { oldValue, newValue in
                viewModel.updateCurrentSelection()
            }
            .navigationTitle("WAD Editor")
#endif
        } detail: {
#if true
            //NavigationStack {
            
            VStack(spacing: 0) {
                SwiftUIGraphicsView(canvas: viewModel.editor.canvas, delegate: viewModel.editor, inputManager: viewModel.editor.inputManager)
                
                VStack(spacing: 0) {
#if os(macOS)
                    let separator = Color(.separatorColor)
#else
                    let separator = Color(.separator)
#endif
                    separator
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                    
                    HStack {
                        Spacer()
                        
                        Button {
                            withAnimation {
                                timelineVisible.toggle()
                            }
                        } label: {
                            Image(systemName: "slider.horizontal.below.rectangle")
                                .padding(8)
                        }
                        .buttonStyle(.borderless)
                        
                    }
                    
                    separator
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                }
                .background {
#if os(macOS)
                    Color(.controlBackgroundColor)
#else
                    Color(.secondarySystemBackground)
                        .ignoresSafeArea()
#endif
                }
                
                
                if timelineVisible {
                    TimelineEditor()
                        .ignoresSafeArea()
                        .transition(.move(edge: .bottom))
                }
            }
                    //.ignoresSafeArea(edges: [.leading, .trailing, .bottom])
#if false
                    .dropDestination(for: URL.self) { items, location in
                        guard let url = items.first else {
                            print("No url specified")
                            return false
                        }
                        
                        guard url.pathExtension.lowercased() == "wad" else {
                            print("Unsupported path extension: \(url.pathExtension)")
                            return false
                        }
                        
                        print("drop \(items) in \(location)")
                        Task {
                            viewModel.loadWAD(at: url)
                        }
                        
                        return true
                    } isTargeted: { inside in
                        //
                    }
#else
                    .dropDestination(for: TransferItem.self) { items, location in
                        guard let url = items.first else {
                            print("No url specified")
                            return false
                        }
                        
                        guard url.url.pathExtension.lowercased() == "wad" else {
                            print("Unsupported path extension: \(url.url.pathExtension)")
                            return false
                        }
                        
                        //guard let pathUrl = URL(string: url.url.path()) else {
                        //    print("Could not create path url: \(url.url.path())")
                        //    return false
                        //}
                        
                        print("read \(url.url.path())")
                        print("drop \(items) in \(location)")
                        Task {
                            viewModel.loadWAD(at: url.url)
                        }
                        
                        return true
                    } isTargeted: { inside in
                        //
                    }
#endif

            //}
            //.navigationTitle("Perview")
#else
            //Color.pink
            SwiftUIGraphicsView(canvas: viewModel.editor.canvas, delegate: viewModel.editor, inputManager: viewModel.editor.inputManager)
                .ignoresSafeArea(edges: [.leading, .trailing, .bottom])
                //.toolbar {
                //    ToolbarItem(id: "run", placement: .secondaryAction) {
                //        ControlGroup {
                //            HStack(spacing: 0) {
                //
                //                Button(action: {
                //                    //
                //                }, label: {
                //                    Image(systemName: "play.fill")
                //                })
                //
                //                Button(action: {
                //                    //
                //                }, label: {
                //                    Image(systemName: "gearshape.fill")
                //                })
                //            }
                //        } label: {
                //            Label("Edits", systemImage: "gearshape")
                //        }
                //    }
                //}
                //.toolbarRole(.editor)
#endif
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            let timeTaken = await ContinuousClock().measure {
                await viewModel.loadTestData()
            }
            print("Import time taken: \(timeTaken)")
        }
    }
}

#Preview {
    ContentView()
}
