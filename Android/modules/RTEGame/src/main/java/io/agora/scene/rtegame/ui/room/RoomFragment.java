package io.agora.scene.rtegame.ui.room;

import android.annotation.SuppressLint;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.Html;
import android.text.Spanned;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewStub;
import android.view.inputmethod.EditorInfo;
import android.webkit.WebView;

import androidx.activity.result.ActivityResultLauncher;
import androidx.annotation.DrawableRes;
import androidx.annotation.MainThread;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.constraintlayout.widget.ConstraintLayout;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.vectordrawable.graphics.drawable.Animatable2Compat;

import com.bumptech.glide.Glide;
import com.bumptech.glide.RequestBuilder;
import com.bumptech.glide.load.DataSource;
import com.bumptech.glide.load.engine.GlideException;
import com.bumptech.glide.load.resource.gif.GifDrawable;
import com.bumptech.glide.request.RequestListener;
import com.bumptech.glide.request.RequestOptions;
import com.bumptech.glide.request.target.CustomTarget;
import com.bumptech.glide.request.target.Target;
import com.bumptech.glide.request.transition.Transition;

import io.agora.example.base.BaseRecyclerViewAdapter;
import io.agora.example.base.BaseUtil;
import io.agora.rtc2.RtcEngine;
import io.agora.scene.rtegame.GlobalViewModel;
import io.agora.scene.rtegame.R;
import io.agora.scene.rtegame.base.BaseFragment;
import io.agora.scene.rtegame.bean.GameApplyInfo;
import io.agora.scene.rtegame.bean.GameInfo;
import io.agora.scene.rtegame.bean.GiftInfo;
import io.agora.scene.rtegame.bean.PKApplyInfo;
import io.agora.scene.rtegame.bean.RoomInfo;
import io.agora.scene.rtegame.databinding.GameFragmentRoomBinding;
import io.agora.scene.rtegame.databinding.GameItemRoomMessageBinding;
import io.agora.scene.rtegame.ui.room.donate.DonateDialog;
import io.agora.scene.rtegame.ui.room.game.GameListDialog;
import io.agora.scene.rtegame.ui.room.tool.MoreDialog;
import io.agora.scene.rtegame.util.BlurTransformation;
import io.agora.scene.rtegame.util.EventObserver;
import io.agora.scene.rtegame.util.GameUtil;
import io.agora.scene.rtegame.util.GiftUtil;
import io.agora.scene.rtegame.util.ViewStatus;
import io.agora.scene.rtegame.view.LiveHostCardView;
import io.agora.scene.rtegame.view.LiveHostLayout;

public class RoomFragment extends BaseFragment<GameFragmentRoomBinding> {

    private static final float recyclerViewHeightOnWidthPercent = 210 / 375f;

    private RoomViewModel mViewModel;

    private BaseRecyclerViewAdapter<GameItemRoomMessageBinding, CharSequence, MessageHolder> mMessageAdapter;

    private RoomInfo currentRoom;
    private boolean aMHost;
    private boolean shouldShowInputBox = false;
    private AlertDialog currentDialog;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        GlobalViewModel mGlobalModel = GameUtil.getAndroidViewModel(this);
        // hold current RoomInfo
        if (mGlobalModel.roomInfo.getValue() != null)
            currentRoom = mGlobalModel.roomInfo.getValue().peekContent();
        if (currentRoom == null) {
            findNavController().navigate(R.id.action_roomFragment_to_roomCreateFragment);
            return null;
        }
        mViewModel = GameUtil.getViewModel(this, RoomViewModel.class, new RoomViewModelFactory(requireContext(), currentRoom));
        //  See if current user is the host
        aMHost = currentRoom.getUserId().equals(mViewModel.localUser.getUserId());

        return super.onCreateView(inflater, container, savedInstanceState);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        initView();
        initListener();
    }

    private void initView() {
//        setRoomBgd(true, GameUtil.getBgdByRoomBgdId(currentRoom.getId()));
//        Glide.with(this).load(mViewModel.localUser.getAvatar())
//                .centerCrop()
//                .placeholder(R.mipmap.game_ic_launcher_round).into(mBinding.layoutRoomInfo.avatarHostFgRoom);
        mBinding.layoutRoomInfo.nameHostFgRoom.setText(currentRoom.getTempUserName());

        // config game view
        new Handler(Looper.getMainLooper()).post(() -> {
            if (mBinding != null) {
                ConstraintLayout.LayoutParams lp = (ConstraintLayout.LayoutParams) mBinding.recyclerViewFgRoom.getLayoutParams();
                lp.matchConstraintPercentHeight = 1F;
                lp.height = (int) (mBinding.getRoot().getMeasuredWidth() * recyclerViewHeightOnWidthPercent);
                mBinding.recyclerViewFgRoom.setLayoutParams(lp);

                int dp12 = (int) BaseUtil.dp2px(12);
                // ?????? Game View ?????????????????? (+ 12dp)
                int topMargin = (int) (mBinding.layoutRoomInfo.getRoot().getBottom() + dp12);
                // Game Mode ????????????????????????????????????
                int marginBottom = mBinding.getRoot().getMeasuredHeight() - mBinding.btnExitFgRoom.getTop() + dp12;
                // Game View ??????
                int height = mBinding.btnExitFgRoom.getTop() - lp.height - dp12 * 2 - topMargin;
                mBinding.hostContainerFgRoom.initParams(topMargin, height, marginBottom, mBinding.recyclerViewFgRoom.getPaddingLeft());
            }
        });

        mMessageAdapter = new BaseRecyclerViewAdapter<>(null, MessageHolder.class);
        mBinding.recyclerViewFgRoom.setAdapter(mMessageAdapter);
        // Android 12 over_scroll animation is phenomenon
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S)
            mBinding.recyclerViewFgRoom.setOverScrollMode(View.OVER_SCROLL_NEVER);

        hideBtnByCurrentRole();
    }

    private void hideBtnByCurrentRole() {
        mBinding.btnGameFgRoom.setVisibility(aMHost ? View.VISIBLE : View.GONE);
        mBinding.btnMoreFgRoom.setVisibility(aMHost ? View.VISIBLE : View.GONE);
        mBinding.btnDonateFgRoom.setVisibility(aMHost ? View.GONE : View.VISIBLE);
    }

    private void initListener() {
        handleWindowInset();

        // ????????????
        mBinding.editTextFgRoom.setOnEditorActionListener((v, actionId, event) -> {
            if (actionId == EditorInfo.IME_ACTION_DONE || (event != null && event.getKeyCode() == KeyEvent.KEYCODE_ENTER)) {
                String msg = v.getText().toString().trim();
                if (!msg.isEmpty())
                    insertUserMessage(msg);
                BaseUtil.hideKeyboardCompat(v);
                v.setText("");
            }
            return false;
        });
        // "??????"??????
        mBinding.btnMoreFgRoom.setOnClickListener(v -> new MoreDialog().show(getChildFragmentManager(), MoreDialog.TAG));
        // "??????"??????
        mBinding.btnGameFgRoom.setOnClickListener(v -> new GameListDialog().show(getChildFragmentManager(), GameListDialog.TAG));
        // "????????????"??????
        mBinding.btnExitGameFgRoom.setOnClickListener(v -> mViewModel.requestExitGame());
        // "????????????"??????
        mBinding.btnExitPkFgRoom.setOnClickListener(v -> mViewModel.endPK());
        // "??????"??????
        mBinding.btnDonateFgRoom.setOnClickListener(v -> new DonateDialog().show(getChildFragmentManager(), DonateDialog.TAG));
        // "???????????????"??????????????????
        mBinding.btnExitFgRoom.setOnClickListener(v -> requireActivity().onBackPressed());
        mBinding.editTextFgRoom.setShowSoftInputOnFocus(true);
        // ??????????????????
        mBinding.inputFgRoom.setOnClickListener(v -> {
            shouldShowInputBox = true;
            BaseUtil.showKeyboardCompat(mBinding.inputLayoutFgRoom);
        });
        // RTC engine ???????????????
        mViewModel.mEngine().observe(getViewLifecycleOwner(), this::onRTCInit);
        // ???????????????==???????????????
        mViewModel.subRoomInfo().observe(getViewLifecycleOwner(), this::onSubHostJoin);
        // ????????????
        mViewModel.gift().observe(getViewLifecycleOwner(), new EventObserver<>(this::onGiftUpdated));

        // ???????????????????????????
        if (aMHost) {
            // ????????????
            mViewModel.applyInfo().observe(getViewLifecycleOwner(), this::onPKApplyInfoChanged);
            mViewModel.currentGame().observe(getViewLifecycleOwner(), this::onGameInfoChanged);
        } else {
            mViewModel.gameShareInfo().observe(getViewLifecycleOwner(), this::onGameShareInfoChanged);
            mViewModel.localHostId().observe(getViewLifecycleOwner(), this::onLocalHostJoin);
        }

        mViewModel.viewStatus().observe(getViewLifecycleOwner(), viewStatus -> {
            if (viewStatus instanceof ViewStatus.Message)
                insertNewMessage(((ViewStatus.Message) viewStatus).msg);
            else if (viewStatus instanceof ViewStatus.Error) {
                BaseUtil.toast(requireContext(), ((ViewStatus.Error) viewStatus).msg);
                findNavController().popBackStack();
            }
        });

        mViewModel.gameStartUrl.observe(getViewLifecycleOwner(), url -> {
            WebView webView = mBinding.hostContainerFgRoom.webViewHostView;
            if (webView != null) {
                webView.loadUrl(url.getContentIfNotHandled());
            }
        });
    }

    private void onGameShareInfoChanged(GameInfo gameInfo) {
        if (gameInfo == null) return;
        if (gameInfo.getStatus() == GameInfo.START) {
            insertNewMessage("????????????????????????");
            needGameView(true);
            mViewModel.startGame();
        } else if (gameInfo.getStatus() == GameInfo.END) {
            insertNewMessage("????????????????????????");
            needGameView(false);
        }
    }

    //<editor-fold desc="?????? ??????">
    private void onPKApplyInfoChanged(PKApplyInfo pkApplyInfo) {
        if (currentDialog != null) currentDialog.dismiss();
        if (pkApplyInfo == null) return;
        if (pkApplyInfo.getStatus() == PKApplyInfo.APPLYING) {
            showPKDialog(pkApplyInfo);
        } else if (pkApplyInfo.getStatus() == PKApplyInfo.REFUSED) {
            insertNewMessage("???????????????");
        }
    }

    /**
     * ???????????????
     */
    private void showPKDialog(PKApplyInfo pkApplyInfo) {
        if (pkApplyInfo.getRoomId().equals(currentRoom.getId())) {
            insertNewMessage(getString(R.string.game_ready_message));
            currentDialog = new AlertDialog.Builder(requireContext()).setMessage(R.string.game_ready_message).setCancelable(false)
                    .setNegativeButton(android.R.string.cancel, (dialog, which) -> {
                        mViewModel.cancelApplyPK(pkApplyInfo);
                        dialog.dismiss();
                    }).show();
        } else {
            currentDialog = new AlertDialog.Builder(requireContext()).setMessage(getString(R.string.game_accept_message, pkApplyInfo.getUserName())).setCancelable(false)
                    .setPositiveButton(android.R.string.ok, (dialog, which) -> {
                        mViewModel.acceptApplyPK(pkApplyInfo);
                        dialog.dismiss();
                    })
                    .setNegativeButton(android.R.string.cancel, (dialog, which) -> {
                        mViewModel.cancelApplyPK(pkApplyInfo);
                        dialog.dismiss();
                    }).show();
        }
    }
    //</editor-fold>

    //<editor-fold desc="????????????">
    private void onGameInfoChanged(GameApplyInfo currentGame) {
        if (currentGame == null) return;
        BaseUtil.logD("game status->" + currentGame.getStatus());
        if (!aMHost) {
            return;
        }
        if (currentGame.getStatus() == GameApplyInfo.PLAYING) {
            needGameView(true);
            mViewModel.startGame();
        } else if (currentGame.getStatus() == GameApplyInfo.END) {
            needGameView(false);
        }
    }

    private void needGameView(boolean need) {
        if (need) {
            mBinding.hostContainerFgRoom.createWebView();
            WebView webViewHostView = mBinding.hostContainerFgRoom.webViewHostView;
            if (webViewHostView != null)
                webViewHostView.addJavascriptInterface(new AgoraJsBridge(mViewModel), "agoraJSBridge");
            onLayoutTypeChanged(LiveHostLayout.Type.DOUBLE_IN_GAME);
        } else {
            mBinding.hostContainerFgRoom.removeWebView();
            onLayoutTypeChanged(mBinding.hostContainerFgRoom.getChildCount() == 2 ? LiveHostLayout.Type.DOUBLE : mBinding.hostContainerFgRoom.getType());
        }
    }
    //</editor-fold>


    /**
     * ?????? || ????????????==???????????????
     * ???????????? ==???????????????
     */
    private void onGiftUpdated(GiftInfo giftInfo) {
        if (giftInfo == null) return;

        mBinding.giftImageFgRoom.setVisibility(View.VISIBLE);

        String giftDesc = GiftUtil.getGiftDesc(requireContext(), giftInfo);
        if (giftDesc != null) insertNewMessage(giftDesc);

        if (!aMHost) {
            int giftId = GiftUtil.getGiftIdFromGiftInfo(requireContext(), giftInfo);
            Glide.with(this).asGif().load(GiftUtil.getGifByGiftId(giftId))
                    .listener(new RequestListener<GifDrawable>() {
                        @Override
                        public boolean onLoadFailed(@Nullable GlideException e, Object model, Target<GifDrawable> target, boolean isFirstResource) {
                            mBinding.giftImageFgRoom.setVisibility(View.GONE);
                            return false;
                        }

                        @Override
                        public boolean onResourceReady(GifDrawable resource, Object model, Target<GifDrawable> target, DataSource dataSource, boolean isFirstResource) {
                            resource.setLoopCount(1);
                            resource.registerAnimationCallback(new Animatable2Compat.AnimationCallback() {
                                @Override
                                public void onAnimationEnd(Drawable drawable) {
                                    super.onAnimationEnd(drawable);
                                    mBinding.giftImageFgRoom.setVisibility(View.GONE);
                                }
                            });
                            return false;
                        }
                    })
                    .into(mBinding.giftImageFgRoom);
        }
    }

    /**
     * RTC ???????????????
     */
    private void onRTCInit(RtcEngine engine) {
        BaseUtil.logD("onRTCInit");
        if (engine == null) findNavController().popBackStack();
        else {
            insertNewMessage("RTC ???????????????");
            // ????????????????????????View????????????
            if (aMHost) initLocalView();
            mViewModel.joinRoom(mViewModel.localUser);
        }
    }

    /**
     * ?????? View ?????????
     * ?????????????????????
     */
    @MainThread
    private void initLocalView() {
        LiveHostCardView view = mBinding.hostContainerFgRoom.createHostView();
        onLayoutTypeChanged(LiveHostLayout.Type.HOST_ONLY);
        mViewModel.setupLocalView(view.renderTextureView);
        insertNewMessage("??????????????????");
    }

    /**
     * ????????????
     */
    @MainThread
    private void onLocalHostJoin(Integer uid) {
        BaseUtil.logD("uid:" + uid);
        if (uid == null) return;
        insertNewMessage("?????????????????????" + currentRoom.getTempUserName() + "?????????");
        LiveHostLayout liveHost = mBinding.hostContainerFgRoom;

        LiveHostCardView view = liveHost.createHostView();
        onLayoutTypeChanged(liveHost.getChildCount() == 1 ? LiveHostLayout.Type.HOST_ONLY : liveHost.getType());
        mViewModel.setupRemoteView(view.renderTextureView, currentRoom, true);
    }

    /**
     * ??????????????????
     */
    @MainThread
    private void onSubHostJoin(@Nullable RoomInfo subRoomInfo) {
        BaseUtil.logD("room status->" + (subRoomInfo == null));
        LiveHostLayout container = mBinding.hostContainerFgRoom;
        // remove subHostView
        if (subRoomInfo == null) {
            insertNewMessage("????????????");
            onLayoutTypeChanged(LiveHostLayout.Type.HOST_ONLY);
        } else {
            insertNewMessage("???????????????????????????" + subRoomInfo.getTempUserName() + "?????????");
            LiveHostCardView view = container.createSubHostView();
            onLayoutTypeChanged(container.getChildCount() == 2 ? LiveHostLayout.Type.DOUBLE : container.getType());
            mViewModel.setupRemoteView(view.renderTextureView, subRoomInfo, false);
        }
    }

    /**
     * ??????????????????
     * ?????????????????????
     */
    private void insertUserMessage(String msg) {
        mViewModel.sendBarrage(msg);
        Spanned userMessage = Html.fromHtml(getString(R.string.game_user_msg, mViewModel.localUser.getName(), msg));
        insertNewMessage(userMessage);
    }

    /**
     * ?????????????????????
     */
    private void insertNewMessage(CharSequence msg) {
        mMessageAdapter.addItem(msg);
        int count = mMessageAdapter.getItemCount();
        if (count > 0)
            mBinding.recyclerViewFgRoom.smoothScrollToPosition(count - 1);
    }

    private void onLayoutTypeChanged(LiveHostLayout.Type type) {
        BaseUtil.logD(System.currentTimeMillis() + "onLayoutTypeChanged:" + type.ordinal());
        mBinding.hostContainerFgRoom.setType(type);
        adjustMessageWidth(type == LiveHostLayout.Type.HOST_ONLY);

        if (aMHost) {
            if (type == LiveHostLayout.Type.HOST_ONLY) {
                mBinding.btnGameFgRoom.setVisibility(View.VISIBLE);
                mBinding.btnExitPkFgRoom.setVisibility(View.GONE);
                mBinding.btnExitGameFgRoom.setVisibility(View.GONE);
            } else if (type == LiveHostLayout.Type.DOUBLE) {
                mBinding.btnGameFgRoom.setVisibility(View.VISIBLE);
                mBinding.btnExitGameFgRoom.setVisibility(View.GONE);
                mBinding.btnExitPkFgRoom.setVisibility(View.VISIBLE);
            } else {
                mBinding.btnGameFgRoom.setVisibility(View.GONE);
                mBinding.btnExitGameFgRoom.setVisibility(View.VISIBLE);
                mBinding.btnExitPkFgRoom.setVisibility(View.GONE);
            }
        }
    }

    @SuppressLint("NotifyDataSetChanged")
    private void adjustMessageWidth(boolean fullWidth) {
        int leftPadding = mBinding.recyclerViewFgRoom.getPaddingLeft();
        int desiredPaddingEnd = fullWidth ? leftPadding : 0;
        mBinding.recyclerViewFgRoom.setPaddingRelative(leftPadding, 0, desiredPaddingEnd, 0);
        ConstraintLayout.LayoutParams lp = (ConstraintLayout.LayoutParams) mBinding.recyclerViewFgRoom.getLayoutParams();
        lp.matchConstraintPercentWidth = fullWidth ? 0.6f : 0.44f;
        mBinding.recyclerViewFgRoom.setLayoutParams(lp);
        mBinding.getRoot().post(() -> mBinding.recyclerViewFgRoom.requestLayout());
    }

    private void setRoomBgd(boolean blurring, @DrawableRes int drawableId) {
        RequestBuilder<Drawable> load = Glide.with(this).asDrawable().load(drawableId);
        if (blurring)
            load = load.apply(RequestOptions.bitmapTransform(new BlurTransformation(requireContext())));

        load.into(new CustomTarget<Drawable>() {
            @Override
            public void onResourceReady(@NonNull Drawable resource, @Nullable Transition<? super Drawable> transition) {
                mBinding.getRoot().setBackground(resource);
            }

            @Override
            public void onLoadCleared(@Nullable Drawable placeholder) {

            }
        });

    }

    private void handleWindowInset() {
        // ????????????
        ViewCompat.setOnApplyWindowInsetsListener(mBinding.getRoot(), (v, insets) -> {
            Insets inset = insets.getInsets(WindowInsetsCompat.Type.systemBars());
            // ????????????
            mBinding.containerOverlayFgRoom.setPadding(inset.left, inset.top, inset.right, inset.bottom);
            // ??????????????????????????????
            boolean imeVisible = insets.isVisible(WindowInsetsCompat.Type.ime());
            if (imeVisible) {
                if (shouldShowInputBox) {
                    mBinding.inputLayoutFgRoom.setVisibility(View.VISIBLE);
                    mBinding.inputLayoutFgRoom.requestFocus();
                    int desiredY = -insets.getInsets(WindowInsetsCompat.Type.ime()).bottom;
                    mBinding.inputLayoutFgRoom.setTranslationY(desiredY);
                }
            } else {
                shouldShowInputBox = false;
                if (mBinding.inputLayoutFgRoom.getVisibility() == View.VISIBLE) {
                    mBinding.inputLayoutFgRoom.setVisibility(View.GONE);
                    mBinding.inputLayoutFgRoom.clearFocus();
                }
            }
            return WindowInsetsCompat.CONSUMED;
        });
    }

}
