import { downloadLinks } from "@/lib/links";

export function DownloadButtons() {
  const { ios, extensionStore, extensionZip } = downloadLinks;
  return (
    <div className="flex flex-col gap-3 sm:flex-row">
      {ios ? (
        <a href={ios} target="_blank" rel="noreferrer" className="btn-primary">
           Download iOS App
        </a>
      ) : (
        <span className="btn-ghost cursor-default opacity-70" title="Link coming soon">
           iOS App — coming soon
        </span>
      )}

      <a
        href={extensionStore || extensionZip}
        target="_blank"
        rel="noreferrer"
        className="btn-ghost"
        download={extensionStore ? undefined : true}
      >
        🧩 Get the Chrome Extension
      </a>
    </div>
  );
}
