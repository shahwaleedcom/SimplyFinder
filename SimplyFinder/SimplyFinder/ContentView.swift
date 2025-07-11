import SwiftUI
import CoreData
import PhotosUI
import UniformTypeIdentifiers
import UIKit

typealias PlatformImage = UIImage

// MARK: - ItemType Enum

enum ItemType: Int16, CaseIterable, Identifiable {
    case text, photo, camera, video, document
    var id: Int16 { rawValue }
    var label: String { ["Text", "Photo", "Camera", "Video", "Document"][Int(rawValue)] }
    var icon: String { ["character.cursor.ibeam", "photo", "camera", "video", "doc"][Int(rawValue)] }
    var color: Color { [.teal, .yellow, .green, .purple, .orange][Int(rawValue)] }
}

// MARK: - Core Data Stack (CloudKit)

final class CoreDataStack {
    static let shared = CoreDataStack()
    let container: NSPersistentCloudKitContainer
    var ctx: NSManagedObjectContext { container.viewContext }
    private init() {
        let model = NSManagedObjectModel()

        // Folder Entity
        let folderEntity = NSEntityDescription()
        folderEntity.name = "Folder"
        folderEntity.managedObjectClassName = NSStringFromClass(Folder.self)
        let folderId = NSAttributeDescription()
        folderId.name = "id"
        folderId.attributeType = .UUIDAttributeType
        folderId.isOptional = false
        folderId.defaultValue = UUID()
        let folderName = NSAttributeDescription()
        folderName.name = "name"
        folderName.attributeType = .stringAttributeType
        folderName.isOptional = false
        folderName.defaultValue = "Folder"
        folderEntity.properties = [folderId, folderName]

        // JarItem Entity
        let itemEntity = NSEntityDescription()
        itemEntity.name = "JarItem"
        itemEntity.managedObjectClassName = NSStringFromClass(JarItem.self)
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .UUIDAttributeType
        idAttr.isOptional = false
        idAttr.defaultValue = UUID()
        let keyAttr = NSAttributeDescription()
        keyAttr.name = "key"
        keyAttr.attributeType = .stringAttributeType
        keyAttr.isOptional = false
        keyAttr.defaultValue = ""
        let typeAttr = NSAttributeDescription()
        typeAttr.name = "type"
        typeAttr.attributeType = .integer16AttributeType
        typeAttr.isOptional = false
        typeAttr.defaultValue = 0
        let textAttr = NSAttributeDescription()
        textAttr.name = "textValue"
        textAttr.attributeType = .stringAttributeType
        textAttr.isOptional = true
        let fileNameAttr = NSAttributeDescription()
        fileNameAttr.name = "fileName"
        fileNameAttr.attributeType = .stringAttributeType
        fileNameAttr.isOptional = true
        let fileDataAttr = NSAttributeDescription()
        fileDataAttr.name = "fileData"
        fileDataAttr.attributeType = .binaryDataAttributeType
        fileDataAttr.isOptional = true
        fileDataAttr.allowsExternalBinaryDataStorage = true
        let createdAttr = NSAttributeDescription()
        createdAttr.name = "created"
        createdAttr.attributeType = .dateAttributeType
        createdAttr.isOptional = false
        createdAttr.defaultValue = Date()

        // Relationship: Folder <->> JarItem
        let folderToItems = NSRelationshipDescription()
        folderToItems.name = "items"
        folderToItems.destinationEntity = itemEntity
        folderToItems.minCount = 0
        folderToItems.maxCount = 0 // to-many
        folderToItems.deleteRule = .cascadeDeleteRule
        folderToItems.isOptional = true

        let itemToFolder = NSRelationshipDescription()
        itemToFolder.name = "folder"
        itemToFolder.destinationEntity = folderEntity
        itemToFolder.minCount = 0
        itemToFolder.maxCount = 1
        itemToFolder.deleteRule = .nullifyDeleteRule
        itemToFolder.isOptional = true

        folderToItems.inverseRelationship = itemToFolder
        itemToFolder.inverseRelationship = folderToItems

        folderEntity.properties.append(folderToItems)
        itemEntity.properties = [idAttr, keyAttr, typeAttr, textAttr, fileNameAttr, fileDataAttr, createdAttr, itemToFolder]

        model.entities = [folderEntity, itemEntity]
        container = NSPersistentCloudKitContainer(name: "JarData", managedObjectModel: model)
        let desc = container.persistentStoreDescriptions.first!
        desc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        desc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        desc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.meez.SimplyFinder")
        container.loadPersistentStores { storeDesc, err in
            if let err = err {
                print("Core Data Store load error: \(err)")
                fatalError("Store load error: \(err)")
            } else {
                print("Core Data store loaded: \(storeDesc)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    func save() {
        let ctx = container.viewContext
        if ctx.hasChanges { try? ctx.save() }
    }
}

// MARK: - NSManagedObject Classes

@objc(Folder)
final class Folder: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var items: Set<JarItem>?
}

@objc(JarItem)
final class JarItem: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var key: String
    @NSManaged var type: Int16
    @NSManaged var textValue: String?
    @NSManaged var fileName: String?
    @NSManaged var fileData: Data?
    @NSManaged var created: Date
    @NSManaged var folder: Folder?
    var itemType: ItemType { ItemType(rawValue: type) ?? .text }
}

// MARK: - ContentView (Folder Browser)

struct ContentView: View {
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.name, ascending: true)],
        animation: .default
    ) private var folders: FetchedResults<Folder>
    @State private var showAddFolder = false
    @State private var newFolderName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(folders) { folder in
                    NavigationLink(destination: FolderDetailView(folder: folder)) {
                        Label(folder.name, systemImage: "folder.fill")
                            .font(.headline)
                    }
                }
                .onDelete { idx in
                    for i in idx { ctx.delete(folders[i]) }
                    CoreDataStack.shared.save()
                }
            }
            .navigationTitle("Folders")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddFolder) {
                NavigationStack {
                    Form {
                        Section(header: Text("Folder Name")) {
                            TextField("Folder", text: $newFolderName)
                        }
                    }
                    .navigationTitle("New Folder")
                    .navigationBarItems(
                        leading: Button("Cancel") { showAddFolder = false },
                        trailing: Button("Add") {
                            let folder = Folder(context: ctx)
                            folder.id = UUID()
                            folder.name = newFolderName.isEmpty ? "Folder" : newFolderName
                            CoreDataStack.shared.save()
                            showAddFolder = false
                            newFolderName = ""
                        }.disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                    )
                }
            }
        }
    }
}

// MARK: - FolderDetailView (Thumb Reach Add Menu)

struct FolderDetailView: View {
    @ObservedObject var folder: Folder
    @Environment(\.managedObjectContext) private var ctx
    @State private var showMenu = false
    @State private var addType: ItemType?
    @State private var showSheet = false
    @State private var tempKey = ""
    @State private var tempValue = ""
    @State private var tempFileData: Data?
    @State private var tempFileName: String?
    @State private var tempUIImage: PlatformImage?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showCameraPicker = false
    @State private var cameraMediaType: CameraMediaType = .photo
    @State private var cameraImage: UIImage?
    @State private var cameraVideoURL: URL?
    @State private var showCameraActionSheet = false
    @Namespace private var plusButtonNS

    var items: [JarItem] { (folder.items ?? []).sorted { $0.created > $1.created } }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            VStack(spacing: 0) {
                List {
                    ForEach(items) { item in
                        HStack(spacing: 14) {
                            Image(systemName: item.itemType.icon)
                                .foregroundColor(item.itemType.color)
                                .font(.title3)
                            VStack(alignment: .leading) {
                                Text(item.key).font(.headline)
                                if item.itemType == .text, let t = item.textValue {
                                    Text(t).foregroundColor(.secondary).lineLimit(1)
                                } else if let n = item.fileName {
                                    Text(n).foregroundColor(.secondary).lineLimit(1)
                                }
                            }
                            Spacer()
                            if (item.itemType == .photo || item.itemType == .video || item.itemType == .camera),
                               let d = item.fileData,
                               let uiimg = UIImage(data: d) {
                                Image(uiImage: uiimg)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { idx in
                        let arr = items
                        for i in idx { ctx.delete(arr[i]) }
                        CoreDataStack.shared.save()
                    }
                }
                .listStyle(.plain)
                .padding(.bottom, 90)
                Spacer(minLength: 0)
            }

            // Thumb reach menu (bottom right)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ZStack {
                        if showMenu {
                            Color.black.opacity(0.20)
                                .ignoresSafeArea()
                                .onTapGesture { withAnimation { showMenu = false } }
                                .transition(.opacity)
                        }
                        // Arc menu pops up from bottom right corner
                        ForEach(Array(ItemType.allCases.enumerated()), id: \.element.id) { idx, item in
                            if showMenu {
                                MenuOptionButton(item: item, angle: thumbMenuAngle(idx), distance: 100)
                                    .matchedGeometryEffect(id: item.id, in: plusButtonNS)
                                    .onTapGesture {
                                        addType = item
                                        showMenu = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.21) {
                                            if item == .camera {
                                                showCameraActionSheet = true
                                            } else {
                                                showSheet = true
                                            }
                                        }
                                    }
                            }
                        }
                        Button(action: {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) { showMenu.toggle() }
                        }) {
                            Image(systemName: showMenu ? "xmark" : "plus")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 84, height: 84)
                                .background(
                                    LinearGradient(gradient: Gradient(colors: [Color.purple, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(Circle())
                                .shadow(radius: 14)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(showMenu ? 1.08 : 1)
                        .accessibilityLabel("Add Item")
                        .padding(.trailing, 18)
                        .padding(.bottom, 24)
                    }
                    // Ensures arc and buttons are not clipped
                    .frame(width: 180, height: 220, alignment: .bottomTrailing)
                    .padding(.trailing, 10)
                    .padding(.bottom, 10)
                }
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        // Add Text
        .sheet(isPresented: Binding(get: { showSheet && addType == .text }, set: { showSheet = $0 })) {
            NavigationStack {
                Form {
                    Section(header: Text("Key")) { TextField("Enter key", text: $tempKey) }
                    Section(header: Text("Value")) { TextEditor(text: $tempValue).frame(minHeight: 80) }
                }
                .navigationTitle("Add Text")
                .navigationBarItems(
                    leading: Button("Cancel") { clearInputs() },
                    trailing: Button("Add") {
                        let obj = JarItem(context: ctx)
                        obj.id = UUID()
                        obj.key = tempKey
                        obj.type = ItemType.text.rawValue
                        obj.textValue = tempValue
                        obj.created = Date()
                        obj.folder = folder
                        CoreDataStack.shared.save()
                        clearInputs()
                    }
                    .disabled(tempKey.isEmpty || tempValue.isEmpty)
                )
            }
            .frame(minWidth: 340, minHeight: 320)
        }
        // Add Photo (from library)
        .photosPicker(isPresented: Binding(get: { showSheet && addType == .photo }, set: { showSheet = $0 }), selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) {
            if let item = photoPickerItem {
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let uiimg = UIImage(data: data) {
                        tempUIImage = uiimg
                        tempFileData = data
                        tempFileName = "Photo-\(Date().timeIntervalSince1970).jpg"
                        presentKeyInputSheet(for: .photo)
                    }
                }
            }
        }
        // Add Video (from library)
        .photosPicker(isPresented: Binding(get: { showSheet && addType == .video }, set: { showSheet = $0 }), selection: $photoPickerItem, matching: .videos)
        .onChange(of: photoPickerItem) {
            if let item = photoPickerItem {
                Task {
                    if let url = try? await item.loadTransferable(type: URL.self), let data = try? Data(contentsOf: url) {
                        tempFileData = data
                        tempFileName = url.lastPathComponent
                        tempUIImage = UIImage(systemName: "video")
                        presentKeyInputSheet(for: .video)
                    }
                }
            }
        }
        // Add Document
        .sheet(isPresented: Binding(get: { showSheet && addType == .document }, set: { showSheet = $0 })) {
            DocumentPicker { url in
                tempFileName = url.lastPathComponent
                tempFileData = try? Data(contentsOf: url)
                tempUIImage = nil
                presentKeyInputSheet(for: .document)
            }
        }
        // Camera
        .confirmationDialog("Camera", isPresented: $showCameraActionSheet) {
            Button("Take Photo") { cameraMediaType = .photo; showCameraPicker = true }
            Button("Record Video") { cameraMediaType = .video; showCameraPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraView(mediaType: cameraMediaType, image: $cameraImage, videoURL: $cameraVideoURL)
                .ignoresSafeArea()
                .onDisappear {
                    if cameraMediaType == .photo, let img = cameraImage, let data = img.jpegData(compressionQuality: 0.94) {
                        tempFileData = data
                        tempUIImage = img
                        tempFileName = "Camera-\(Date().timeIntervalSince1970).jpg"
                        presentKeyInputSheet(for: .camera)
                    } else if cameraMediaType == .video, let url = cameraVideoURL, let data = try? Data(contentsOf: url) {
                        tempFileData = data
                        tempUIImage = UIImage(systemName: "video")
                        tempFileName = url.lastPathComponent
                        presentKeyInputSheet(for: .camera)
                    }
                }
        }
        // Key input sheet (for all types except text)
        .sheet(isPresented: $showingKeyInput) {
            NavigationStack {
                Form {
                    Section(header: Text("Key")) { TextField("Enter key", text: $tempKey) }
                }
                .navigationTitle("Add \(addType?.label ?? "")")
                .navigationBarItems(
                    leading: Button("Cancel") { clearInputs() },
                    trailing: Button("Add") {
                        let obj = JarItem(context: ctx)
                        obj.id = UUID()
                        obj.key = tempKey
                        obj.type = addType?.rawValue ?? 0
                        obj.fileName = tempFileName
                        obj.fileData = tempFileData
                        obj.created = Date()
                        obj.folder = folder
                        CoreDataStack.shared.save()
                        clearInputs()
                    }.disabled(tempKey.isEmpty || tempFileData == nil)
                )
            }
            .frame(minWidth: 340, minHeight: 180)
        }
    }

    @State private var showingKeyInput = false
    private func presentKeyInputSheet(for type: ItemType) {
        addType = type
        showSheet = false
        showCameraPicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showingKeyInput = true }
    }
    private func clearInputs() {
        tempKey = ""
        tempValue = ""
        tempFileData = nil
        tempFileName = nil
        tempUIImage = nil
        photoPickerItem = nil
        cameraImage = nil
        cameraVideoURL = nil
        showSheet = false
        addType = nil
        showingKeyInput = false
    }
    // Spread arc from 210 to 130 degrees (counterclockwise, keeps buttons visible in bottom right)
    private func thumbMenuAngle(_ idx: Int) -> Double {
        let count = Double(ItemType.allCases.count)
        let start = 210.0  // up/left from bottom right
        let sweep = -80.0  // arc up to about 130 degrees
        return start + (sweep / (count > 1 ? Double(count-1) : 1)) * Double(idx)
    }
}

// MARK: - MenuOptionButton

struct MenuOptionButton: View {
    let item: ItemType
    let angle: Double
    let distance: CGFloat
    @State private var appear = false
    var body: some View {
        let offset = CGPoint(
            x: cos(angle * .pi / 180) * (appear ? distance : 0),
            y: -sin(angle * .pi / 180) * (appear ? distance : 0)
        )
        return VStack {
            Image(systemName: item.icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 68, height: 68)
                .background(item.color.gradient)
                .clipShape(Circle())
                .shadow(radius: 12)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.45), lineWidth: 3)
                )
                .scaleEffect(appear ? 1 : 0.3)
                .opacity(appear ? 1 : 0)
                .onAppear { withAnimation(.easeOut(duration: 0.2).delay(0.05)) { appear = true } }
                .onDisappear { appear = false }
            Text(item.label)
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)
                .offset(y: -10)
        }
        .offset(x: offset.x, y: offset.y)
        .animation(.spring(response: 0.35, dampingFraction: 0.68), value: appear)
    }
}

// MARK: - Document Picker & Camera

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.content, UTType.item], asCopy: true)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        return controller
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { parent.onPick(url) }
        }
    }
}

enum CameraMediaType { case photo; case video }
struct CameraView: UIViewControllerRepresentable {
    var mediaType: CameraMediaType
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    @Binding var videoURL: URL?
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if parent.mediaType == .photo {
                if let img = info[.originalImage] as? UIImage { parent.image = img }
            } else if parent.mediaType == .video {
                if let url = info[.mediaURL] as? URL { parent.videoURL = url }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if mediaType == .photo {
            picker.sourceType = .camera
            picker.mediaTypes = ["public.image"]
            picker.cameraCaptureMode = .photo
        } else if mediaType == .video {
            picker.sourceType = .camera
            picker.mediaTypes = ["public.movie"]
            picker.cameraCaptureMode = .video
            picker.videoQuality = .typeMedium
        }
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
