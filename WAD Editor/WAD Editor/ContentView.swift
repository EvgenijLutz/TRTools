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
import UniformTypeIdentifiers


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
    var shared: Bool = false
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


enum GLTFExportError: Error {
    case dataNotFound
    case unsupportedItemType
}

class GLTFExportData {
    let wad: WAD
    let item: NavigatorItem
    
    init(wad: WAD, item: NavigatorItem) {
        self.wad = wad
        self.item = item
    }
}

class GLTFExportPromise: NSObject, NSFilePromiseProviderDelegate {
    deinit {
        print("Deinit promise")
    }
    
    
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        guard let data = filePromiseProvider.userInfo as? GLTFExportData else {
            return "file.glb"
        }
        
        func modelName(for modelIndex: Int) -> String {
            guard let identifier = data.wad.findModel(modelIndex)?.identifier else {
                return "Model #\(modelIndex)"
            }
            
            return String(describing: identifier)
        }
        
        let name = switch data.item.value {
        case .section: "Section"
        case .texturePage(let textureIndex): "Texture #\(textureIndex)"
        case .mesh(let meshIndex, _): "Mesh #\(meshIndex)"
        case .model(let modelIndex): modelName(for: modelIndex)
        case .animation(_, let animationIndex): "Animation #\(animationIndex)"
        case .staticObject(let staticObject): String(describing: staticObject)
        }
        
        return name + ".glb"
    }
    
    
//    nonisolated func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping ((any Error)?) -> Void) {
//        do {
//            try "suck a dick".write(to: url, atomically: true, encoding: .utf8)
//            completionHandler(nil)
//        }
//        catch {
//            completionHandler(error)
//        }
//    }
    
    
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL) async throws {
        guard let data = filePromiseProvider.userInfo as? GLTFExportData else {
            throw GLTFExportError.dataNotFound
        }
        
        switch data.item.value {
        case .model(let modelIndex):
            let data = try await data.wad.exportGLTFModel(modelIndex)
            try data.write(to: url)
            //try "suck a dick".write(to: url, atomically: true, encoding: .utf8)
            
        default:
            throw GLTFExportError.unsupportedItemType
        }
        
    }
    
}


@MainActor
@Observable class ViewModel {
    let editor = Editor()
    
    //@Published var path: NavigationPath
    let provider = NavigatorItemProvider()
    
    
    var navigatorList: [NavigatorItem] = []
    var selection: UUID? = nil
    
    let gltfPromise = GLTFExportPromise()
    
    
    init() {
    }
    
    deinit {
        print("Deinit")
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
                    return NavigatorItem(name: name, value: .model(modelIndex), shared: true, items: [
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


extension UTType {
    /// TRLE WAD file format. Defined in the Project settings -> Info
    static let wad = UTType(importedAs: "com.coredesign.custom-file-extensions.wad")
}


struct TransferItem: Transferable, Equatable, Sendable {
    
    public var url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .wad) { item in
            print("Invoke transferRepresentation")
            let name = item.file.lastPathComponent
            let tmpUrl = FileManager.default.temporaryDirectory.appending(component: name)
            if FileManager.default.fileExists(atPath: tmpUrl.path()) {
                try FileManager.default.removeItem(at: tmpUrl)
            }
            
            try FileManager.default.copyItem(at: item.file, to: tmpUrl)
            
            return .init(url: tmpUrl)
        }
    }
}


extension View {
    func wadDropDestination(_ viewModel: ViewModel) -> some View {
        self.dropDestination(for: TransferItem.self) { items, location in
            guard let url = items.first else {
                print("No url specified")
                return false
            }
            
            // Make sure that the file has .wad extension. Should actually never happen, since the TransferItem struct already restricts the file type
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
    }
    
}


struct ViewportView: View {
    @State var viewModel: ViewModel
    @State var timelineVisible: Bool = false
    
    
    var body: some View {
        VStack(spacing: 0) {
            SwiftUIGraphicsView(canvas: viewModel.editor.canvas, delegate: viewModel.editor, inputManager: viewModel.editor.inputManager)
                .wadDropDestination(viewModel)
#if os(macOS)
                let separator = Color(.separatorColor)
#else
                let separator = Color(.separator)
#endif
            
            
#if false
            VStack(spacing: 0) {
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
#endif
            
            
            if timelineVisible {
                VStack(spacing: 0) {
                    separator
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                    
                    TimelineEditor { model in
                        viewModel.editor.connectTimeline(model: model)
                    }
                    .ignoresSafeArea()
                }
                .transition(.move(edge: .bottom))
            }
        }
        //.ignoresSafeArea(edges: [.leading, .trailing, .bottom])
        .toolbar {
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
    }
}


struct ContentView: View {
    @State var viewModel = ViewModel()
    
    @State var meshesExpanded: Bool = true
    @State var path = NavigationPath()
    @State var navValue: Bool = false
    
    
    var body: some View {
        NavigationSplitView {
#if true
            //NavigationLink(value: navValue) {
            //    Text(navValue ?? "none")
            //}
            
            NavigatorTestView(dataProvider: viewModel.provider) { [weak viewModel] item in
                guard let viewModel else {
                    return
                }
                
                switch item.value {
                case .section:
                    break
                
                case .texturePage(_):
                    break
                    
                //case .mesh(let mesh, let type):
                //    break
                //
                //case .model(let model):
                //    break
                //case .animation(let model, let animation):
                //    break
                //
                //case .staticObject(let staticObject):
                //    break
                default:
                    navValue = true
                    viewModel.selection = item.id
                    viewModel.updateCurrentSelection()
                }
                //if item.value != .section {
                //    navValue = true
                //    viewModel.selection = item.id
                //    viewModel.updateCurrentSelection()
                //}
                //else {
                //    navValue = false
                //}
            } exportItemAction: { [weak viewModel] item in
                guard let viewModel else {
                    return nil
                }
                
                guard let wad = viewModel.editor.wad else {
                    return nil
                }
                
                //let provider = NSFilePromiseProvider(fileType: UTType.url.identifier, delegate: viewModel.gltfPromise)
                let provider = NSFilePromiseProvider(fileType: "org.khronos.gltf.glb", delegate: viewModel.gltfPromise)
                provider.userInfo = GLTFExportData(wad: wad, item: item)
                return provider
            }
            .ignoresSafeArea()
            .navigationTitle("WAD Editor")
            .navigationDestination(isPresented: $navValue) {
                ViewportView(viewModel: viewModel)
            }
            // Import wad
            //.toolbar {
            //    ToolbarItem(placement: .navigation) {
            //        Button {
            //            //
            //        } label: {
            //            Image(systemName: "square.and.arrow.down")
            //        }
            //    }
            //}
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
#endif
        } detail: {
#if false
            ViewportView(viewModel: viewModel)
#else
            ZStack(alignment: .center) {
                Text("Select an item in the list on the left to see the details")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
#endif
        }
        .navigationSplitViewStyle(.balanced)
#if DEBUG
        .task {
            let timeTaken = await ContinuousClock().measure {
                await viewModel.loadTestData()
            }
            print("Import time taken: \(timeTaken)")
        }
#endif
        .wadDropDestination(viewModel)
    }
}

#Preview {
    ContentView()
}
