package android.print;

import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;

import java.io.File;
import java.io.IOException;

/**
 * Drives a PrintDocumentAdapter straight to a PDF file, with no print dialog.
 *
 * <p>LayoutResultCallback and WriteResultCallback have constructors that are public at runtime but
 * hidden from the SDK stubs, which leaves them package-private to code compiled against android.jar.
 * This class lives in android.print so it can subclass them. Must be called on the UI thread.</p>
 */
public final class StageWebViewPdfWriter {

	public interface Listener {
		void onFinished(boolean success, String error);
	}

	private StageWebViewPdfWriter() {}

	public static void write(final PrintDocumentAdapter adapter, final PrintAttributes attributes, final File file, final Listener listener) {
		adapter.onStart();
		adapter.onLayout(null, attributes, null, new PrintDocumentAdapter.LayoutResultCallback() {
			@Override
			public void onLayoutFinished(PrintDocumentInfo info, boolean changed) {
				final ParcelFileDescriptor descriptor;
				try {
					descriptor = ParcelFileDescriptor.open(file,
						ParcelFileDescriptor.MODE_CREATE | ParcelFileDescriptor.MODE_TRUNCATE | ParcelFileDescriptor.MODE_READ_WRITE);
				} catch (IOException error) {
					finish(adapter, null, listener, false, error.toString());
					return;
				}

				adapter.onWrite(new PageRange[] { PageRange.ALL_PAGES }, descriptor, new CancellationSignal(),
					new PrintDocumentAdapter.WriteResultCallback() {
						@Override
						public void onWriteFinished(PageRange[] pages) {
							finish(adapter, descriptor, listener, pages != null && pages.length > 0, null);
						}

						@Override
						public void onWriteFailed(CharSequence error) {
							finish(adapter, descriptor, listener, false, String.valueOf(error));
						}

						@Override
						public void onWriteCancelled() {
							finish(adapter, descriptor, listener, false, "Writing the PDF was cancelled");
						}
					});
			}

			@Override
			public void onLayoutFailed(CharSequence error) {
				finish(adapter, null, listener, false, String.valueOf(error));
			}

			@Override
			public void onLayoutCancelled() {
				finish(adapter, null, listener, false, "Print layout was cancelled");
			}
		}, null);
	}

	private static void finish(PrintDocumentAdapter adapter, ParcelFileDescriptor descriptor, Listener listener, boolean success, String error) {
		if (descriptor != null) {
			try {
				descriptor.close();
			} catch (IOException ignored) {
			}
		}

		adapter.onFinish();
		listener.onFinished(success, error);
	}
}
