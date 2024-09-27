import './index.css';

import { EventMessage, EventType } from '@azure/msal-browser';
import { MsalProvider } from "@azure/msal-react";
import setupAxiosInterceptors from 'app/config/axiosInterceptors';
import { MsalAuthenticationPayload, msalInstance } from "app/config/msalConfig";
import reportWebVitals from 'app/config/reportWebVitals';
import getStore from 'app/config/store';
import { AuthenticationSlice } from 'app/shared/reducers/authentication.reducer';
import React from 'react';
import { Container, createRoot } from 'react-dom/client';
import { Provider } from 'react-redux';
import { BrowserRouter } from "react-router-dom";

import App from './app';

msalInstance.addEventCallback((message: EventMessage) => {
  if (message.eventType === EventType.LOGIN_SUCCESS || message.eventType === EventType.ACQUIRE_TOKEN_SUCCESS) {
      const msalPayload = message?.payload as MsalAuthenticationPayload;
      if (msalPayload && 'accessToken' in msalPayload && 'account' in msalPayload) {
        const {username, tenantId, name } = msalPayload.account;
        const user = { username, tenantId, name };
        const payload = {user, token: msalPayload.accessToken};
        getStore().dispatch(AuthenticationSlice.actions.loginSession(payload));
      } else {
        getStore().dispatch(AuthenticationSlice.actions.logoutSession());
      }
  } else if(message.eventType.includes("Failure")) {
      console.error(message);
      getStore().dispatch(AuthenticationSlice.actions.logoutSession());
  }
});


const initialize = async () => {
  await msalInstance.initialize();    
  const store = getStore();
  setupAxiosInterceptors();
    
  const rootElem = document.getElementById('root') as Container;
  const root = createRoot(rootElem);

  root.render(
    <React.StrictMode>
      <Provider store={store}>
        <MsalProvider instance={msalInstance}>
          <BrowserRouter>
            <App />
          </BrowserRouter>
        </MsalProvider>
      </Provider>
    </React.StrictMode>
  );
}

initialize();



// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
reportWebVitals();
